module AWSDSL
  class Stack
    include DSL
    attributes :description, :vars
    sub_components :role, :role_profile, :elasticache, :vpc

    def mixin_profiles
      @roles.each do |role|
        role.include_profiles.each do |profile|
          role_profile = @role_profiles.find { |rp| rp.name == profile }
          role_profile.block.bind(role).call
        end
      end
    end
  end
end
