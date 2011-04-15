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
      attributes = Copycat.stringify_keys(attributes)
      
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

    def self.for_user(user)
      projects = []
      redis.smembers("projects").each do |p|
        projects << get(p) if authorised? user, p
      end

      projects.sort { |a, b| a["name"] <=> b["name"] }
    end

    def self.authorised?(user, api_key)
      user["superuser"] || redis.sismember("project_users:#{api_key}", user["username"])
    end

    def self.configuration_block(project)
      <<EOF
      Copycopter::Client.configure do |config|
  config.api_key = "#{project["api_key"]}"
  config.host    = "#{Copycat.configuration.hostname}"
  config.port    = #{Copycat.configuration.port}
  config.secure  = #{Copycat.configuration.ssl ? "true" : "false"}
end
EOF
    end
  end
end
