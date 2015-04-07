stack 'logs' do
  description 'logstash cluster'
  ssl_cert_arn = 'arn:aws:iam::account_id::certificate'
  zone_arn = 'arn:aws:route53:::hostedzone/zone_id'
  snapshot_bucket_arn = 'arn:aws:s3:::snapshot_bucket'
  cloudtrail_queue_arn = 'arn:aws:sqs:ap-southeast-2:account_id:queue'

  vpc 'logs' do
    region 'ap-southeast-2'
    subnet 'public' do
      az 'a', 'b'
    end
    subnet 'private' do
      az 'a', 'b'
      igw false
    end
  end

  role_profile 'es_comms' do
    security_group 'sg-id'
    subnets 'subnet-id'
    vpc 'vpc-id'
  end

  role_profile 'es_bucket' do
    policy_statement effect: 'Allow', action: 's3:ListBucket', resource: snapshot_bucket_arn
    policy_statement effect: 'Allow',
                     action: %w(s3:GetObject s3:PutObjecs3:DeleteObject s3:DeleteObject),
                     resource: "#{snapshot_bucket_arn}/*"
  end

  role_profile 'ec2_discovery' do
    policy_statement effect: 'Allow', action: 'ec2:DescribeInstances', resource: '*'
  end

  role 'logstash' do
    include_profile 'ec2_discovery', 'es_comms'
    load_balancer 'logstash' do
      listener port: 80
      listener port: 443, proto: 'HTTPS', cert: ssl_cert_arn
      listener port: 9000, proto: 'TCP'
      dns_record name: 'logstash.zone.com', zone: 'zone-id'
      health_check target: 'HTTP:80/health'
    end
    policy_statement effect: 'Allow', action: 'sqs:*', resource: cloudtrail_queue_arn
    min_size 2
    max_size 4
    tgt_size 2
    update_policy pause_time: '5M'
    instance_type 't2.micro'
    chef_provisioner runlist: 'logstash'
  end

  role 'elasticsearch' do
    include_profile 'ec2_discovery', 'es_bucket', 'es_comms'
    load_balancer 'elasticsearch' do
      listener port: 9200
      health_check target: 'HTTP:9200/'
      dns_record name: 'elasticsearch.zone.com', zone: 'zone-id'
      security_group 'sg-id'
      internal true
    end
    min_size 3
    max_size 5
    tgt_size 5
    update_policy pause_time: '10M', min_inservice: 3
    instance_type 't2.micro'
    chef_provisioner runlist: 'elasticsearch'
    allow role: 'logstash', ports: 9200
    allow role: 'utility', ports: 9200
    allow role: 'elasticsearch', ports: 9200
  end

  role 'utility' do
    include_profile 'es_bucket', 'es_comms'
    policy_statement effect: 'Allow',
                     action: [
                       'route53:ChangeResourceRecordSets',
                       'route53:GetHostedZone',
                       'route53:ListResourceRecordSets'
                     ],
                     resource: zone_arn
    policy_statement effect: 'Allow', action: 'route53:ListHostedZones', resource: '*'
    min_size 0
    max_size 1
    tgt_size 1
    update_policy min_inservice: 0
    instance_type 't2.micro'
    chef_provisioner runlist: 'utility'
  end

  elasticache 'redis' do
    vpc 'vpc-id'
    subnet 'subnet-id'
    engine 'redis'
    node_type 't2.micro'
    allow role: 'logstash'
  end
end
