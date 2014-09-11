# Copyright (c) 2014 Fidelity Investments.

require 'chef/resource'

class Chef
    class Resource

        class Storage < Chef::Resource
            
            include SysUtils::Helper

            def initialize(name, run_context=nil)
                super
                
                @resource_name = :storage

                if !run_context.nil?

                    # Check for Xen Hypervisor
                    @provider = nil

                    xe_path = shell("which xe")
                    if !xe_path.empty?

                        fqdn = run_context.node["fqdn"]
                        pool_master_uuid = shell("xe pool-list params=master --minimal")
                        
                        if !pool_master_uuid.empty?

                            hostname = shell("xe host-list params=hostname uuid=#{pool_master_uuid} --minimal")
                            @provider = Chef::Provider::Storage::Xen if fqdn==hostname
                        end
                    end

                    Chef::Application.fatal!("Unable to determine hypervisor type.", 999) if @provider.nil?
                end

                @action = :create
                @allowed_actions = [:create, :attach, :detach, :delete]

                @name = name

                @uuid = nil
                @type = "nfs"
                @default = false
                @shared = true
                @nfs_server = nil
                @nfs_path = nil
                @other_config = { }
            end

            def uuid(arg=nil)
                set_or_return(:uuid, arg, :kind_of => String)
            end

            def type(arg=nil)
                set_or_return(:type, arg, :kind_of => String)
            end

            def default(arg=nil)
                set_or_return(:default, arg, :kind_of => [TrueClass, FalseClass])
            end

            def shared(arg=nil)
                set_or_return(:shared, arg, :kind_of => [TrueClass, FalseClass])
            end

            def nfs_server(arg=nil)
                set_or_return(:nfs_server, arg, :kind_of => String)
            end

            def nfs_path(arg=nil)
                set_or_return(:nfs_path, arg, :kind_of => String)
            end

            def other_config(arg=nil)
                set_or_return(:other_config, arg, :kind_of => Hash)
            end
        end

    end
end
