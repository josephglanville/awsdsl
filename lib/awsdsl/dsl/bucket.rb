module AWSDSL
  class Bucket
    include DSL
    # TODO(jpg): CORS, Lifecycle config etc.
    attributes :bucket_name, :access_control
  end
end
