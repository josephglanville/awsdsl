module AWSDSL
  module CfnHelpers
    def listener_defaults(listener)
      listener[:proto] ||= 'HTTP'
      listener[:instance_port] ||= listener[:port]
      listener[:loadbalancer_port] ||= listener[:port]
      hash = {
        LoadBalancerPort: listener[:loadbalancer_port],
        InstancePort: listener[:instance_port],
        Protocol: listener[:proto]
      }
      hash[:SSLCertificateId] = listener[:cert] if listener[:cert]
      hash
    end

    def health_check_defaults(health_check)
      hash = {
        Target: health_check[:target]
      }
      hash[:HealthyThreshold] = health_check[:healthy_threshold] || 3
      hash[:UnhealthyThreshold] = health_check[:unhealthy_threshold] || 5
      hash[:Interval] = health_check[:interval] || 90
      hash[:Timeout] = health_check[:timeout] || 60
      hash
    end

    def update_policy_defaults(role)
      update_policy = role.update_policy || {}
      return nil if update_policy[:disable] == true
      hash = {}
      hash[:MaxBatchSize] = update_policy[:max_batch] || 1
      hash[:MinInstancesInService] = update_policy[:min_inservice] || role.min_size
      hash[:PauseTime] = update_policy[:pause_time] if update_policy[:pause_time]
    end

    def format_policy_statement(policy_statement)
      Hash[policy_statement.map { |k, v| [k.to_s.capitalize.to_sym, v] }]
    end

    def get_zone_for_record(name)
      r53 = AWS::Route53.new
      zones = r53.hosted_zones.sort_by {|z| z.name.split('.').count }.reverse
      zones.find do |z|
        name.split('.').reverse.take(z.name.split('.').count) == z.name.split('.').reverse
      end
    end
  end
end
