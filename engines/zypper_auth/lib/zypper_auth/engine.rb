module ZypperAuth
  class << self
    def auth_logger
      @logger ||= ::Logger.new('/var/lib/rmt/zypper_auth.log')
      @logger.reopen
      @logger
    end

    def verify_instance(request, logger, system)
      instance_data = Base64.decode64(request.headers['X-Instance-Data'].to_s)

      base_product = system.products.find_by(product_type: 'base')
      return false unless base_product

      cache_key = [request.remote_ip, system.login, base_product.id].join('-')
      cached_result = Rails.cache.fetch(cache_key)
      return cached_result unless cached_result.nil?

      verification_provider = InstanceVerification.provider.new(
        logger,
        request,
        base_product.attributes.symbolize_keys.slice(:identifier, :version, :arch, :release_type),
        instance_data
      )

      verification_provider.instance_valid?
      is_valid = true # log the error only, don't raise auth error (for now)
      Rails.cache.write(cache_key, is_valid, expires_in: 1.hour)
      is_valid
    rescue InstanceVerification::Exception => e
      details = [ "System login: #{system.login}", "IP: #{request.remote_ip}" ]
      details << "Instance ID: #{verification_provider.instance_id}" if verification_provider.instance_id
      details << "Billing info: #{verification_provider.instance_billing_info}" if verification_provider.instance_billing_info

      ZypperAuth.auth_logger.info <<~LOGMSG
        Access to the repos denied: #{e.message}
        #{details.join(', ')}
      LOGMSG

      is_valid = true # log the error only, don't raise auth error (for now)
      Rails.cache.write(cache_key, is_valid, expires_in: 10.minutes)
      is_valid
    rescue StandardError => e
      logger.error('Unexpected instance verification error has occurred:')
      logger.error(e.message)
      logger.error("System login: #{system.login}, IP: #{request.remote_ip}")
      logger.error('Backtrace:')
      logger.error(e.backtrace)
      false
    end

    def plugin_detected?(system, request)
      return true if request.headers['X-Instance-Data']
      system.hw_info&.instance_data.to_s.match(%r{<repoformat>plugin:susecloud</repoformat>})
    end
  end

  class Engine < ::Rails::Engine
    isolate_namespace ZypperAuth
    config.generators.api_only = true

    config.after_initialize do
      ::V3::ServiceSerializer.class_eval do
        alias_method :original_url, :url
        def url
          original_url = original_url()
          return original_url unless @instance_options[:susecloud_plugin]

          url = URI(original_url)
          "plugin:/susecloud?credentials=#{object.name}&path=" + url.path
        end
      end

      # replaces URLs in API response JSON
      Api::Connect::V3::Systems::ActivationsController.class_eval do
        def index
          respond_with(
            @system.activations,
            each_serializer: ::V3::ActivationSerializer,
            base_url: request.base_url,
            include: '*.*',
            susecloud_plugin: ZypperAuth.plugin_detected?(@system, request)
          )
        end
      end

      # replaces URLs in API response JSON
      Api::Connect::V3::Systems::ProductsController.class_eval do
        def render_service
          status = ((request.put? || request.post?) ? 201 : 200)
          # manually setting request method, so respond_with actually renders content also for PUT
          request.instance_variable_set(:@request_method, 'GET')

          respond_with(
            @product.service,
            serializer: ::V3::ServiceSerializer,
            base_url: request.base_url,
            obsoleted_service_name: @obsoleted_service_name,
            status: status,
            susecloud_plugin: ZypperAuth.plugin_detected?(@system, request)
          )
        end
      end

      ServicesController.class_eval do
        alias_method :original_make_repo_url, :make_repo_url

        # replaces URLs in zypper service XML
        def make_repo_url(base_url, repo_local_path, service_name)
          original_url = original_make_repo_url(base_url, repo_local_path, service_name)
          return original_url unless request.headers['X-Instance-Data']

          url = URI(original_url)
          "plugin:/susecloud?credentials=#{service_name}&path=" + url.path
        end

        # additional validation for zypper service XML controller
        before_action :verify_instance
        def verify_instance
          ZypperAuth.verify_instance(request, logger, @system)
          true # don't raise auth errors (for now)
        end
      end

      StrictAuthentication::AuthenticationController.class_eval do
        alias_method :original_path_allowed?, :path_allowed?

        # additional validation for strict_authentication auth subrequest
        def path_allowed?(path)
          return false unless original_path_allowed?(path)
          ZypperAuth.verify_instance(request, logger, @system)
          true # don't raise auth errors (for now)
        end
      end
    end
  end
end
