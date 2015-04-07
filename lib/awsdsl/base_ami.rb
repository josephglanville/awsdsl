module AWSDSL
  module BaseAMI
    DISTROS = %w(ubuntu)

    def self.find(distro)
      send(distro)
    end

    def self.ubuntu
      ec2 = AWS::EC2.new
      ami = ec2.images.with_owner('099720109477')
            .filter('name', 'ubuntu/images/hvm-ssd/ubuntu-trusty-14.04-amd64-server*')
            .sort_by(&:name).last
      ami.id
    end
  end
end
