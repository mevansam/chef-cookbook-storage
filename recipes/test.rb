#
# Cookbook Name:: storage
# Recipe:: test
#

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

## NFS Storage

## Test #1 - create NFS share

# ruby_block "Create shared directories" do
#     block do
#     	sr_uuid = node["xenserver"]["storage"]["nfs"]["uuid"]
#     	if !sr_uuid.nil?
# 			guest_kernel_dir="/var/run/sr-mount/#{sr_uuid}/os-guest-kernels"
# 			shell!("mkdir -p \"#{guest_kernel_dir}\"");
# 			image_dir="/var/run/sr-mount/#{sr_uuid}/images"
# 			shell!("mkdir -p \"#{image_dir}\"");
# 		else
# 			Chef::Application.fatal!("No valid shared NFS storage uuid configured for the node.")
# 		end
# 	end
# 	action :nothing
# end

# storage "c2c245pool_test" do
# 	type       "nfs"
# 	nfs_server "nx245s2.fmr.com"
# 	nfs_path   "/volumes/C2C/c2c245pool1"
# 	notifies   :create, "ruby_block[Create shared directories]"
# end

## Test #2 - delete NFS share

# storage "c2c245pool_test" do
# 	action :delete
# end

## Test #3 - attach to NFS share

# storage "c2c245pool1" do
# 	uuid       "133f0028-7126-a3a9-52fe-1ea7cd6d313c"
# 	type       "nfs"
# 	nfs_server "nx245s2.fmr.com"
# 	nfs_path   "/volumes/C2C/c2c245pool1"
# 	action     :attach
# end

## Test #3 - detach NFS share

# storage "c2c245pool1" do
# 	uuid   "133f0028-7126-a3a9-52fe-1ea7cd6d313c"
# 	action :detach
# end

## Test #4 - attach to shared ISO storage

# storage "c2c245images" do
# 	type       "iso"
# 	nfs_server "nx245s2.fmr.com"
# 	nfs_path   "/volumes/C2C/c2c245pool1"
# 	action     :create
# end

## Test #4 - setach to shared ISO storage

# storage "c2c245images" do
# 	type       "iso"
# 	nfs_server "nx245s2.fmr.com"
# 	nfs_path   "/volumes/C2C/c2c245pool1"
# 	action     :detach
# end
