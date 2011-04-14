module Copycat
  module Projects
    class DuplicateProjectName < Exception; end
    
    def self.redis
      Copycat.redis
    end
    
    def self.random_key
      Digest::MD5.hexdigest("#{Kernel.rand(9999999999999)}.#{Time.now.to_i}")
    end

    def self.create(attributes = {})
      attributes = attributes.inject({}) do |hash, item|
        hash[item[0].to_s] = item[1] # Convert symbolized keys to strings.
        hash
      end

      if redis.sismember "project_names", attributes["name"]
        raise DuplicateProjectName.new
      else
        attributes["api_key"] ||= random_key
        
        redis.set "projects:#{attributes["api_key"]}", attributes.to_json
        redis.sadd "projects", attributes["api_key"]
        redis.sadd "project_names", attributes["name"]
        if attributes["users"]
          attributes["users"].each { |user| assign_user(user, attributes["api_key"]) }
        end
        
        attributes
      end
    end
    
    def self.assign_user(user, api_key)
      if redis.sismember "projects", api_key
        redis.sadd "project_users:#{api_key}", user
      end
    end

    def self.get(api_key)
      json = redis.get("projects:#{api_key}")
      return JSON.parse(json) if json
    end
  end
end