# Copyright (c) 2013-2014 SUSE LLC
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of version 3 of the GNU General Public License as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, contact SUSE LLC.
#
# To contact SUSE about this file by physical or electronic mail,
# you may find current contact information at www.suse.com

require_relative "spec_helper"

describe SystemDescription do
  before(:each) do
    path = "spec/data/descriptions/validation"
    @store = SystemDescriptionStore.new(path)
  end

  describe "validate config file presence" do
    it "validates unextracted description" do
      expect {
        @store.load("config-files-unextracted")
      }.to_not raise_error
    end

    it "validates valid description" do
      expect {
        @store.load("config-files-good")
      }.to_not raise_error
    end

    it "throws error on invalid description" do
      expect {
        @store.load("config-files-bad")
      }.to raise_error(Machinery::Errors::SystemDescriptionValidationFailed) do |error|
        expect(error.to_s).to eq(<<EOT
Error validating description 'config-files-bad'

Scope 'config_files':
  * File 'spec/data/descriptions/validation/config-files-bad/config_files/etc/postfix/main.cf' doesn't exist
EOT
        )
      end
    end
  end

  describe "validate changed managed file presence" do
    it "validates unextracted description" do
      expect {
        @store.load("changed-managed-files-unextracted")
      }.to_not raise_error
    end

    it "validates valid description" do
      expect {
        @store.load("changed-managed-files-good")
      }.to_not raise_error
    end

    it "throws error on invalid description" do
      expect {
        @store.load("changed-managed-files-bad")
      }.to raise_error(Machinery::Errors::SystemDescriptionValidationFailed) do |error|
        expect(error.to_s).to eq(<<EOT
Error validating description 'changed-managed-files-bad'

Scope 'changed_managed_files':
  * File 'spec/data/descriptions/validation/changed-managed-files-bad/changed_managed_files/usr/share/bash/helpfiles/read' doesn't exist
EOT
        )
      end
    end
  end

  describe "validate unmanaged file presence" do
    it "validates unextracted description" do
      expect {
        @store.load("unmanaged-files-unextracted")
      }.to_not raise_error
    end

    it "validates valid description" do
      expect {
        @store.load("unmanaged-files-good")
      }.to_not raise_error
    end

    it "throws error on invalid description" do
      expect {
        @store.load("unmanaged-files-bad")
      }.to raise_error(Machinery::Errors::SystemDescriptionValidationFailed) do |error|
        expect(error.to_s).to eq(<<EOT
Error validating description 'unmanaged-files-bad'

Scope 'unmanaged_files':
  * File 'spec/data/descriptions/validation/unmanaged-files-bad/unmanaged_files/trees/root/.ssh.tgz' doesn't exist
EOT
        )
      end
    end
  end
end