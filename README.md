AWS DSL
======

This project is an opinionated take on running applications on AWS.
It leverages [CloudFormation](http://aws.amazon.com/cloudformation/) and [Gersberms](https://github.com/josephglanville/gersberms) to build your application into an Amazon Machine Image and deploy it on bare EC2 servers.

In a nutshell you declare your infrastructure in a Stackfile, which is a Ruby DSL that describes CloudFormation resources and AMI build instructions.

It is in some ways analagous to OpsWorks however it's less intrusive and focuses on building immutable AMIs and replacing machines during updates rather than updating already running machines by re-running Chef.

That said it you are already using OpsWorks it would be easy to get started using AWS DSL.

Install
-------

For now I recommending using Bundler to install and manage AWS DSL.
Simply add this to your Gemfile

```ruby
gem 'awsdsl', git: 'https://github.com/josephglanville/awsdsl'
```

I will publish the gem to RubyGems when I feel it's stabilized.

Getting Started
---------------

To get started with AWS DSL you need a few things.

* Your application deployable using Chef.
* Your Chef cookbooks managed with Berkshelf.
* Basic understanding of EC2, ELB and any other resources you might need.

Because AWS DSL abstracts away the vast majority of CloudFormation you shouldn't need an indepth understanding of CloudFormation but it doesn't hurt.

Simple Stackfile
----------------

```ruby
stack 'static' do
  description 'static files example'

  vpc 'static' do
    region 'ap-southeast-2'
    subnet 'public' do
      az 'a', 'b'
    end
  end

  role 'nginx' do
    vpc 'static'
    subnet 'public'
    load_balancer 'static' do
      listener port: 80
      health_check target: 'HTTP:80/'
    end
    update_policy min_inservice: 0
    instance_type 't2.micro'
    key_pair 'joseph@reinteractive.net'
    chef_provisioner runlist: 'nginx'
    vars nginx: {
      init_style: 'upstart'
    }
  end
end
```

This simple stack declares a simple role along with provisioning a full VPC.
Said VPC includes 2 subnets across 2 AZs and an Internet Gateway to allow public addressing to work.
It runs the nginx::default recipe when preparing the AMI, providing the contents of vars as the node attributes.

Complex Stackfile
-----------------

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

This much more complex example deploys a full Elasticsearch Logstash Kibana cluster. Along with standing up an Elasticache cluster running Redis.
It uses advanced features like Role Profiles (which are effectively Role mixins) and the powerful "allow" syntax which makes configuring security groups a breeze.

As you can see AWS DSL doesn't get in your way if you need to declare additional policy documents or do advanced things like setup SSL listeners or configure DNS records for your ELBs.

Command Line
------------

Once you have your Stackfile you will need to build the AMIs.

```
bundle exec awsdsl build
```

Then create your stack

```
bundle exec awsdsl create
```

When you build new AMIs or update settings in your Stackfile you can push updates like so

```
bundle exec awsdsl update
```

Philosophy
----------

AWS DSL was written to enable the versioning of infrastructure alongside code.
All infrastructure concerns are declared in the AWS DSL Stackfile including how to configure the application runtime environment which will be built into an AMI.
This is advantagous as updates to code that require infrastructure support can be done in unison.

AWS DSL thinks about your application in terms of Roles. A role is a singular purposed entity in your application and represents a build target and a scaling primitive.
You specify how to package your application into an AMI, tell it how many instances you want to run and any other considerations like security groups and away it goes.

To DRY up this process AWS DSL has Role Profiles. Role Profiles are analagous to mixins (or multiple inheritance if you must), anything you can put in a Role can be put in Role Profile and then you can mixin multiple Role Profiles into a Role with the include_profile keyword.



TODO
----

* cloud-init/cfn-init integration and environment variable system
* build AMIs seperately
* cfndsl section to allow arbitrary resource creation
