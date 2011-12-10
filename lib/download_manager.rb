module DownloadManager
  class << self
    def add down
      update_status down, false
      
      unless ["error", "new", "paused"].include? down.status
        down.save
        return false
      end
      
      down.options["dir"] = dir_for down
      begin
        down.gid             = Aria2.add down.uri, down.options
        down.info["session"] = Aria2.this_session
      rescue Exception => e
        e.message
      else
        down.status     = "added"
        down.started_at = Time.now
        down.save
      end
    end
    
    def status down, keys=[]
      Aria2.status(down.gid, keys) rescue nil
    end
    
    def pause  (down) send_command :pause,   down end
    def resume (down) send_command :resume,  down end
    def remove (down) send_command :remove,  down end
    def files  (down) send_command :files,   down end
    def options(down) send_command :options, down end
    
    def pause_all     () send_no_arg_commad :pause_all      end
    def resome_all    () send_no_arg_commad :resume_all     end
    def global_options() send_no_arg_commad :global_options end
    def global_status () send_no_arg_commad :global_status  end
    def version       () send_no_arg_commad :version        end
    def session       () send_no_arg_commad :session        end
    def shutdown      () send_no_arg_commad :shutdown       end
    
    def send_command command, down
      Aria2.send command, down.gid
    rescue Exception => e
      e.message
    end
    
    def send_no_arg_commad command
      Aria2.send command
    rescue Exception => e
      e.message
    end
    
    def add_all
      Download.to_add.find_each { |down| add down }
    end
    
    def dir_for down
      down.options["dir"] or File.join Aria2Config.fetch(:dir, "/tmp"), down.category.path("/")
    end
    
    def has_valid_gid? down
      same_session = (down.info["session"] == Aria2.this_session) rescue false
      
      if same_session and not down.gid.nil?
        true
      else
        down.gid = nil
        down.info.delete "session"
        false
      end
    end
    
    def update_status down, save=true
      return unless has_valid_gid? down
      
      begin
        keys = ["status", "errorCode", "files"]
        down.status, error, files = Aria2.status(down.gid, keys).values_at(*keys)
      rescue
        return
      end
      
      down.error = nil
      
      case down.status
      when "complete"
        down.files        = files.map { |f| f["path"] }
        down.completed_at = Time.now
      when "error"
        down.error = "ErrorCode: #{error}"
      end
          
      down.save if save
    end
    
    def update_status_all
      Download.to_check.find_each { |down| update_status down }
    end
    
    def remove_files down
      FileUtils.rm_rf down.files
      down.files_removed = true
      down.removed = true
      down.save
    end
    
    def cleanup_files
      Download.to_clean.find_each { |down| remove_files down }
    end
  end
end