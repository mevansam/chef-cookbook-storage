
#
# Author: Mevan Samaratunga
# Email: mevansam@gmail.com
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'chef/provider'
require 'uri/http'
require 'erb'

class Chef
    class Provider

        class Storage

            class Xen < Chef::Provider

                include ERB::Util
                include SysUtils::Helper

                def load_current_resource
                    @current_resource ||= Chef::Resource::Storage.new(new_resource.name)

                    @current_resource.uuid(new_resource.uuid)
                    @current_resource.type(new_resource.type)
                    @current_resource.default(new_resource.default)
                    @current_resource.shared(new_resource.shared)
                    @current_resource.nfs_server(new_resource.nfs_server)
                    @current_resource.nfs_path(new_resource.nfs_path)
                    @current_resource.other_config(new_resource.other_config)

                    @name_is_set = false
                end

                def action_create

                    if exists?
                        shell!("xe sr-param-set uuid=\"#{@current_resource.uuid}\" name-label=\"#{@current_resource.name}\"") if !@name_is_set
                    else 

                        if (!@current_resource.uuid.nil? && !@current_resource.uuid.empty?) || @current_resource.type=="iso"
                            action_attach
                        else
                            # Create new default shared SR
                            @current_resource.uuid( shell( "xe sr-create name-label=\"#{@current_resource.name}\" " + 
                                "content-type=\"user\" type=\"#{@current_resource.type}\" " + 
                                "shared=#{@current_resource.shared} #{device_config_options}" ) )

                            common_config

                            Chef::Log.debug("Created SR with uuid '#{@current_resource.uuid}'.")
                        end

                        new_resource.updated_by_last_action(true)
                    end

                    node.set["xenserver"]["storage"][@current_resource.type]["uuid"] = @current_resource.uuid
                    node.save
                end

                def action_attach

                    if exists?
                        shell!("xe sr-param-set uuid=\"#{@current_resource.uuid}\" name-label=\"#{@current_resource.name}\"") if !@name_is_set
                    else 
                        content_type = "user"

                        case @current_resource.type
                            when "iso"

                                @current_resource.uuid(shell("uuidgen")) if @current_resource.uuid.nil? || @current_resource.uuid.empty?
                                content_type = "iso"

                            when "nfs"

                                uuid = shell("xe sr-probe type=nfs #{device_config_options} | awk '/#{@current_resource.uuid}/ { print $1 }'")

                                Chef::Application.fatal!("Unable to find shared repository with id " + 
                                    "#{@current_resource.uuid} in given NFS share.") if uuid.nil? || uuid.empty?

                                @current_resource.uuid(uuid)
                        end

                        shell!( "xe sr-introduce uuid=#{@current_resource.uuid} name-label=\"#{@current_resource.name}\" " +
                            "content-type=#{content_type} type=#{@current_resource.type} shared=#{@current_resource.shared}" )
                        
                        host_uuid = shell("xe host-list hostname=\"#{node["fqdn"]}\" --minimal")
                        pbd_uuid = shell("xe pbd-create sr-uuid=#{@current_resource.uuid} #{device_config_options} host-uuid=#{host_uuid}")

                        shell!("xe pbd-plug uuid=#{pbd_uuid}")
                        shell!("xe sr-scan uuid=#{@current_resource.uuid}")

                        common_config

                        new_resource.updated_by_last_action(true)
                    end

                    node.set["xenserver"]["storage"][@current_resource.type]["uuid"] = @current_resource.uuid
                    node.save
                end

                def common_config

                    shell!("xe sr-param-set uuid=\"#{@current_resource.uuid}\" #{other_config_options}")
                
                    if @current_resource.default
                        pool_uuid = shell("xe pool-list --minimal")
                        shell!("xe pool-param-set uuid=#{pool_uuid} default-SR=#{@current_resource.uuid}")
                    end
                end

                def action_detach

                    if exists?

                        pbd_uuid = shell("xe pbd-list sr-uuid=\"#{@current_resource.uuid}\" --minimal")
                        if !pbd_uuid.empty?
                            shell!("xe pbd-unplug uuid=\"#{pbd_uuid}\"")
                            shell!("xe pbd-destroy uuid=\"#{pbd_uuid}\"")
                        end
                        shell!("xe sr-forget uuid=\"#{@current_resource.uuid}\"")

                        sr_path = "/var/run/sr-mount/#{@current_resource.uuid}"
                        if Dir.exists?(sr_path) && shell("ls -l #{sr_path} | awk '/total /{ print $2 }'")=="0"
                            shell!("rm -fr #{sr_path}")
                        else
                            Chef::Log.warn("Did not delete the #{sr_path} directory as it was not empty.")
                        end

                        node.set["xenserver"]["storage"][@current_resource.type]["uuid"] = nil
                        node.save

                        new_resource.updated_by_last_action(true)
                    end
                end

                def action_delete

                    if exists?

                        case @current_resource.type
                            when "iso"
                                action_detach
                            else
                                pbd_uuid = shell("xe pbd-list sr-uuid=\"#{@current_resource.uuid}\" --minimal")
                                if !pbd_uuid.empty?
                                    shell!("xe pbd-unplug uuid=\"#{pbd_uuid}\"")
                                    shell!("xe sr-destroy uuid=\"#{@current_resource.uuid}\"")
                                end
                                shell!("xe sr-forget uuid=\"#{@current_resource.uuid}\"")
                        end

                        node.set["xenserver"]["storage"][@current_resource.type]["uuid"] = nil
                        node.save

                        new_resource.updated_by_last_action(true)
                    end
                end

                def exists?

                    uuid = shell("xe sr-list name-label=\"#{@current_resource.name}\" type=\"#{@current_resource.type}\" minimal=true");
                    @name_is_set = !uuid.empty?

                    if !@current_resource.uuid.nil?

                        Chef::Application.fatal!("Given UUID of storage does not match that of storage with name " + 
                            "'@current_resource.name'.", 999) if !uuid.empty? && uuid != @current_resource.uuid

                        uuid = shell("xe sr-list uuid=\"#{@current_resource.uuid}\" type=\"#{@current_resource.type}\" minimal=true");

                    elsif uuid.empty? && @current_resource.type != "nfs" &&
                        !@current_resource.nfs_server.nil? && !@current_resource.nfs_path.nil?

                        # Attempt to locate SR via its NFS location information
                        uuid = shell( "for sr in $(xe sr-list type=#{@current_resource.type} --minimal | sed \"s|,| |\"); do " + 
                            "uuid=$(xe pbd-list sr-uuid=$sr #{device_config_options} params=sr-uuid --minimal); " + 
                            "[ -z \"$uuid\" ] || (echo $uuid); done")                        
                    end

                    @current_resource.uuid(uuid) if !uuid.empty?
                    return !uuid.empty?
                end

                def device_config_options

                    if !@current_resource.nfs_server.nil? && !@current_resource.nfs_path.nil?
                        case @current_resource.type
                            when "iso"
                                return "device-config:location=#{@current_resource.nfs_server}:#{@current_resource.nfs_path}"
                            when "nfs"
                                return "device-config:server=#{@current_resource.nfs_server} device-config:serverpath=#{@current_resource.nfs_path}"
                        end
                    end
                    return ""
                end

                def other_config_options

                    other_config_options = ""
                    sr_other_config = { }

                    if !@current_resource.uuid.nil? && !@current_resource.uuid.empty?

                        sr_other_config = Hash[ shell("xe sr-list uuid=#{@current_resource.uuid} params=other-config --minimal")
                            .split(";").map { |kv| kv.strip.split(":").collect { |v| v.strip } } ]
                    end

                    return ((@current_resource.other_config.select { |k,v| sr_other_config[k] != v })\
                        .each_pair.collect { |k,v| "other-config:#{k}=#{v}" }).join(" ")
                end

            end
        end
    end
end
