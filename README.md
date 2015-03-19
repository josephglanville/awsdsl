AWS DSL
======

This project is an opinionated take on running applications on AWS.
It leverages CloudFormation and Gersberms to build your application into an Amazon Machine Image and deploy it on bare EC2 servers.

Design
------

AWS DSL thinks about your application in terms of Roles. A role is a singular purposed entity in your application and represents a build target and a scaling primitive.
You specify how to package your application into an AMI, tell it how many instances you want to run and any other considerations like security groups and away it goes.

To DRY up this process AWS DSL has Role Profiles. Role Profiles are analagous to mixins, anything you can put in a Role can be put in Role Profile and then you can mixin multiple Role Profiles into a Role with the include_profile keyword.

Currently not implemented but AWS DSL will also support other resources like RDS, Elasticache, DynamoDB and S3 buckets. Automatically creating and managing resources around your application so you can create environments and destroy them at will with all of their dependencies cleaned up.

TODO
----

* AMI building hasn't been implemented yet
* Conveniences like being able to specify security groups and subnets by name
* non-Role resources like RDS etc
* cloud-init/cfn-init integration and environment variable system
