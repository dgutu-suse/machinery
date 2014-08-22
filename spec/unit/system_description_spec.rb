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
  subject { SystemDescription.new("foo") }

  before(:all) do
    @name = "name"
    @description = '{
      "repositories": [
        {
          "alias": "YaST:Head",
          "name": "YaST:Head",
          "url": "http://download.opensuse.org",
          "type": "rpm-md",
          "priority": 99,
          "keep_packages": false,
          "enabled": true,
          "gpgcheck": true,
          "autorefresh": true
        }
      ],
      "packages": [
        {
          "name": "kernel-desktop",
          "version": "3.7.10",
          "release": "1.0",
          "arch": "x86_64",
          "vendor": "SUSE LINUX Products GmbH, Nuernberg, Germany",
          "checksum": "2a3d5b29179daa1e65e391d0a0c1442d"
        }
      ],
      "meta": {
        "format_version": 1,
        "packages": {
          "modified": "2014-02-07T14:04:45Z",
          "hostname": "192.168.122.216"
        }
      }
    }'
    @duplicate_description = '{
      "meta": {
        "format_version": 1
      },
      "packages": [
        {
          "name": "kernel-desktop",
          "version": "3.7.10",
          "release": "1.0",
          "arch": "x86_64",
          "vendor": "SUSE LINUX Products GmbH, Nuernberg, Germany",
          "checksum": "2a3d5b29179daa1e65e391d0a0c1442d"
        },
        {
          "name": "kernel-desktop",
          "version": "3.7.10",
          "release": "1.0",
          "arch": "x86_64",
          "vendor": "SUSE LINUX Products GmbH, Nuernberg, Germany",
          "checksum": "2a3d5b29179daa1e65e391d0a0c1442d"
        }
      ]
    }'
    @empty_description = '{
      "meta": {
        "format_version": 1
      }
    }'
    @mix_struct_hash_descr = '{
      "software": {
        "packages": {
          "foo": "bar"
        }
      },
      "meta": {
        "format_version": 1
      }
    }'
  end

  it "returns empty JSON structure on .new" do
    data = SystemDescription.new("foo")
    expect(data.to_json.delete(' ')).to eq(@empty_description.delete(' '))
  end

  it "provides nested accessors for data attributes" do
    data = SystemDescription.from_json(@name, @description)
    expect(data.repositories.first.alias).to eq("YaST:Head")
  end

  it "supports serialization from and to json" do
    data = SystemDescription.from_json(@name, @description)
    expect(data.to_json.delete(' ')).to eq(@description.delete(' '))
  end

  it "allows mixture of object and hash in json serialization" do
    data = SystemDescription.new("foo")
    data.software = Machinery::Object.new
    data.software.packages = Hash.new
    data.software.packages["foo"] = "bar"
    expect(data.to_json.delete(' ')).to eq(@mix_struct_hash_descr.delete(' '))
  end

  it "raises InvalidSystemDescription if json input does not start with a hash" do
    class SystemDescriptionFooConfig < Machinery::Object; end
    expect { SystemDescription.from_json(@name,
      '[ "system-description-foo", "xxx" ]'
    )}.to raise_error(Machinery::Errors::SystemDescriptionError)
  end

  it "raises SystemDescriptionError on invalid global data in a description" do
    expect {
      SystemDescription.from_json(@name, <<-EOT)
        {
          "meta": {
            "format_version": 1,
            "os": "invalid"
          }
        }
      EOT
    }.to raise_error(Machinery::Errors::SystemDescriptionError)
  end

  it "raises SystemDescriptionError on invalid scope data in a description" do
    expect {
      SystemDescription.from_json(@name, <<-EOT)
        {
          "meta": {
            "format_version": 1
          },
          "os": { }
        }
      EOT
    }.to raise_error(Machinery::Errors::SystemDescriptionError)
  end

  it "doesn't validate incompatible descriptions" do
    expect {
      SystemDescription.from_json(@name, <<-EOT)
        {
          "meta": {
            "os": "invalid"
          }
        }
      EOT
    }.not_to raise_error
  end

  it "raises ValidationError if json validator find duplicate packages" do
    SystemDescription.add_validator "/packages" do |json|
      if json != json.uniq
        raise Machinery::Errors::SystemDescriptionError,
          "The description contains duplicate packages."
      end
    end
    expect { SystemDescription.from_json(@name,
      @duplicate_description
    )}.to raise_error(Machinery::Errors::SystemDescriptionError)
  end

  describe "json parser error handling" do
    it "raises and shows the error position if possible " do
      json = File.read("spec/data/schema/faulty-element.json")
      expect { SystemDescription.from_json(@name, json) }.to raise_error(
        Machinery::Errors::SystemDescriptionError,
        /around line 8:.*"version": "13\.1" \n/m
      )
    end

    it "raises and shows an explanation if an unlocatable issue happened" do
      json = File.read("spec/data/schema/faulty-global-scope.json")
      expect { SystemDescription.from_json(@name, json) }.to raise_error(
        Machinery::Errors::SystemDescriptionError,
        /our JSON  parser isn't able to localize issues like these\.$/m
      )
    end

    it "doesn't show explanation in case of locatable errors" do
      json = File.read("spec/data/schema/faulty-element.json")
      expect { SystemDescription.from_json(@name, json) }.to raise_error(
        Machinery::Errors::SystemDescriptionError,
        /\s+}$/m
      )
    end
  end

  describe "#compatible?" do
    it "returns true if the format_version is good" do
      subject.format_version = SystemDescription::CURRENT_FORMAT_VERSION
      expect(subject.compatible?).to be(true)
    end

    it "returns false if there is no format version defined" do
      subject.format_version = nil
      expect(subject.compatible?).to be(false)
    end

    it "returns false if the format_version does not match the current format version" do
      subject.format_version = SystemDescription::CURRENT_FORMAT_VERSION - 1
      expect(subject.compatible?).to be(false)

      subject.format_version = SystemDescription::CURRENT_FORMAT_VERSION + 1
      expect(subject.compatible?).to be(false)
    end
  end

  describe "#ensure_compatibility!" do
    it "does not raise an exception if the description is compatible" do
      subject.format_version = SystemDescription::CURRENT_FORMAT_VERSION
      expect {
        subject.ensure_compatibility!
      }.to_not raise_error
    end

    it "raises an exception if the description is incompatible" do
      subject.format_version = SystemDescription::CURRENT_FORMAT_VERSION - 1
      expect {
        subject.ensure_compatibility!
      }.to raise_error
    end
  end

  describe "#to_json" do
    it "saves version metadata for descriptions with format version" do
      description = SystemDescription.from_json("name", <<-EOT)
        {
          "meta": {
            "format_version": 1
          }
        }
      EOT

      json = JSON.parse(description.to_json)

      expect(json["meta"]["format_version"]).to eq(1)
    end

    it "doesn't save version metadata for descriptions without format version" do
      description = SystemDescription.from_json("name", "{}")

      json = JSON.parse(description.to_json)

      has_format_version = json.has_key?("meta") && json["meta"].has_key?("format_version")
      expect(has_format_version).to be(false)
    end
  end

  describe "#scopes" do
    it "returns a sorted list of scopes which are available in the system description" do
      description = SystemDescription.from_json(@name, @description)
      expect(description.scopes).to eq(["packages", "repositories"])
    end
  end

  describe "#assert_scopes" do
    it "checks the system description for completeness" do
      full_description = SystemDescription.from_json(@name, @description)
      [
        ["repositories"],
        ["packages"],
        ["repositories", "packages"]
      ].each do |missing|
        expect {
          description = full_description.dup
          missing.each do |element|
            description.send("#{element}=", nil)
          end
          description.assert_scopes("repositories", "packages")
        }.to raise_error(
           Machinery::Errors::SystemDescriptionError,
           /: #{missing.join(", ")}\./)
      end
    end
  end

  describe "#short_os_version" do
    it "checks for the os scope" do
      json = <<-EOF
        {
        }
      EOF
      description = SystemDescription.from_json("name", json)

      expect {
        description.short_os_version
      }.to raise_error(Machinery::Errors::SystemDescriptionError)
    end

    it "parses openSUSE versions" do
      json = <<-EOF
        {
          "os": {
            "name": "openSUSE 13.1 (Bottle)",
            "version": "13.1 (Bottle)"
          }
        }
      EOF
      description = SystemDescription.from_json("name", json)

      expect(description.short_os_version).to eq("13.1")
    end

    it "parses SLES versions with SP" do
      json = <<-EOF
        {
          "os": {
            "name": "SUSE Linux Enterprise Server 11",
            "version": "11 SP3"
          }
        }
      EOF
      description = SystemDescription.from_json("name", json)

      expect(description.short_os_version).to eq("sles11sp3")
    end

    it "parses SLES versions without SP" do
      json = <<-EOF
        {
          "os": {
            "name": "SUSE Linux Enterprise Server 12",
            "version": "12"
          }
        }
      EOF
      description = SystemDescription.from_json("name", json)

      expect(description.short_os_version).to eq("sles12")
    end

    it "omits Beta/RC versions" do
      json = <<-EOF
        {
          "os": {
            "name": "SUSE Linux Enterprise Server 12",
            "version": "12 Beta 7"
          }
        }
      EOF
      description = SystemDescription.from_json("name", json)

      expect(description.short_os_version).to eq("sles12")
    end
  end

  describe "#scope_extracted?" do
    let(:description) {
      json = <<-EOF
        {
          "config_files": []
        }
      EOF
      description = SystemDescription.from_json("name", json)
    }

    it "returns true" do
      description.store = double(file_store: "/path/to/foo")
      expect(description.scope_extracted?("config_files")).to be(true)
    end

    it "returns false" do
      description.store = double(file_store: nil)
      expect(description.scope_extracted?("config_files")).to be(false)
    end
  end

  describe "#os_object" do
    it "returns Os object for SLES 12" do
      json = <<-EOF
        {
          "os": {
            "name": "SUSE Linux Enterprise Server 12"
          }
        }
      EOF
      description = SystemDescription.from_json("name", json)

      expect(description.os_object).to be_a(OsSles12)
    end

    it "returns Os object for SLES 11" do
      json = <<-EOF
        {
          "os": {
            "name": "SUSE Linux Enterprise Server 11"
          }
        }
      EOF
      description = SystemDescription.from_json("name", json)

      expect(description.os_object).to be_a(OsSles11)
    end

    it "returns Os object for openSUSE 13.1" do
      json = <<-EOF
        {
          "os": {
            "name": "openSUSE 13.1 (Bottle)"
          }
        }
      EOF
      description = SystemDescription.from_json("name", json)

      expect(description.os_object).to be_a(OsOpenSuse13_1)
    end

    it "raises exception for invalid os name" do
      json = <<-EOF
        {
          "os": {
            "name": "invalid name"
          }
        }
      EOF
      description = SystemDescription.from_json("name", json)

      expect{ description.os_object }.to(
        raise_error(Machinery::Errors::SystemDescriptionError))
    end
  end
end
