AWS DSL
======

This project is an opinionated take on running applications on AWS.
It leverages CloudFormation and Gersberms to build your application into an Amazon Machine Image and deploy it on bare EC2 servers.

Design
------

AWS DSL thinks about your application in terms of Roles. A role is a singular purposed entity in your application and represents a build target and a scaling primitive.
You specify how to package your application into an AMI, tell it how many instances you want to run and any other considerations like security groups and away it goes.

To DRY up this process AWS DSL has Role Profiles. Role Profiles are analagous to mixins (or multiple inheritance if you must), anything you can put in a Role can be put in Role Profile and then you can mixin multiple Role Profiles into a Role with the include_profile keyword.

Currently not implemented but AWS DSL will also support other resources like RDS, Elasticache, DynamoDB and S3 buckets. Automatically creating and managing resources around your application so you can create environments and destroy them at will with all of their dependencies cleaned up.

Example
-------

```ruby
stack 'logs' do
  description 'logstash cluster'
  ssl_cert_arn = 'arn:aws:iam::account_id::certificate'
  zone_arn = 'arn:aws:route53:::hostedzone/zone_id'
  snapshot_bucket_arn = 'arn:aws:s3:::snapshot_bucket'
  cloudtrail_queue_arn = 'arn:aws:sqs:ap-southeast-2:account_id:queue'

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
    block_device name: '/dev/sda1', size: 20
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
```

TODO
----

* cloud-init/cfn-init integration and environment variable system
