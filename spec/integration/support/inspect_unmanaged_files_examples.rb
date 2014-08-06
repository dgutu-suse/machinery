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

shared_examples "inspect unmanaged files" do |base|
  let(:ignore_list) {
    [
      "var/lib/logrotate.status",
      "var/spool/cron/lastrun/cron.daily"
    ]
  }
  describe "--scope=unmanaged-files" do
    def parse_md5sums(output)
      output.split("\n").map { |e| e.split.first }
    end
    test_tarball = File.join(Machinery::ROOT, "../machinery/spec/data/unmanaged_files/unmanaged-files.tgz")

    it "extracts list of unmanaged files" do
      measure("Inspect system") do
        @machinery.run_command(
          "machinery inspect #{@subject_system.ip} --scope=unmanaged-files --extract-files",
          as: "vagrant"
        )
      end

      actual_output = @machinery.run_command(
        "machinery show #{@subject_system.ip} --scope=unmanaged-files",
        as: "vagrant", stdout: :capture
      )
      # Remove timestamp, so comparison doesn't fail on that.
      # In the future we want to use the Machinery matcher for this, but right
      # now it doesn't generate useable diffs, so doing it manually here for now
      actual = actual_output.split("\n").select { |i| i.start_with?("  * ") }

      # Ignore some sporadically appearing files
      actual.reject! { |file| ignore_list.any? { |i| file.include?(i) } }

      expected_output = File.read("spec/data/unmanaged_files/#{base}")
      expected = expected_output.split("\n").select { |i| i.start_with?("  * ") }
      expect(actual).to match_array(expected)
    end

    it "extracts meta data of unmanaged files" do
      actual_output = @machinery.run_command(
        "machinery show #{@subject_system.ip} --scope=unmanaged-files",
        as: "vagrant", stdout: :capture
      )

      # check meta data of a few files
      # complete comparisons aren't possible because of differing log sizes and similar
      file_example = File.read("spec/data/unmanaged_files/output_file.#{base}")
      dir_example  = File.read("spec/data/unmanaged_files/output_dir.#{base}")
      link_example = File.read("spec/data/unmanaged_files/output_link.#{base}")

      expect(actual_output).to include(file_example)
      expect(actual_output).to include(dir_example)
      expect(actual_output).to include(link_example)
    end

    it "filters directories which consist temporary or automatically generated files" do
      entries = nil

      measure("Get list of unmanaged-files") do
        entries = @machinery.run_command(
          "machinery show #{@subject_system.ip} --scope=unmanaged-files",
          as: "vagrant", stdout: :capture
        )
      end

      expect(entries).to_not include("  - /tmp")
      expect(entries).to_not include("  - /var/tmp")
      expect(entries).to_not include("  - /lost+found")
      expect(entries).to_not include("  - /var/run")
      expect(entries).to_not include("  - /var/lib/rpm")
      expect(entries).to_not include("  - /.snapshots")
    end

    it "extracts unmanaged files as tarballs" do
      # test extracted files
      actual_tarballs = nil
      actual_filestgz_list = nil
      measure("Gather information about extracted files") do
        actual_tarballs = @machinery.run_command(
          "cd ~/.machinery/#{@subject_system.ip}/unmanaged-files/trees; find -type f",
          as: "vagrant", stdout: :capture
        ).split("\n")

        actual_filestgz_list = @machinery.run_command(
          "tar -tf ~/.machinery/#{@subject_system.ip}/unmanaged-files/files.tgz",
          as: "vagrant", stdout: :capture
        ).split("\n")
      end
      # Ignore some sporadically appearing files
      actual_filestgz_list.reject! { |file| ignore_list.any? { |i| file.include?(i) } }

      expected_tarballs = []
      expected_filestgz_list = []
      expected_output = File.read("spec/data/unmanaged_files/#{base}")
      expected_output.split("\n").each do |line|
        if line.start_with?("  * ")
          file = line.match(/^  \* \/(.*) \(\w{3,4}\)$/)[1]
          if line.end_with?(" (dir)")
            expected_tarballs << "./#{file.chomp("/")}.tgz"
          else
            expected_filestgz_list << file
          end
        end
      end
      expect(actual_tarballs).to match_array(expected_tarballs)
      expect(actual_filestgz_list).to match_array(expected_filestgz_list)


      # check content of test tarball
      tmp_dir = Dir.mktmpdir("unmanaged-files", "/tmp")
      expected_output = `cd "#{tmp_dir}"; tar -xf "#{test_tarball}"; md5sum "#{tmp_dir}/srv/www/htdocs/test/"*`
      FileUtils.rm_r(tmp_dir)
      expected_md5sums = parse_md5sums(expected_output)

      output = @machinery.run_command(
        "cd /tmp; tar -xf ~/.machinery/#{@subject_system.ip}/unmanaged-files/trees/srv/www/htdocs/test.tgz; md5sum /tmp/srv/www/htdocs/test/*",
        as: "vagrant", stdout: :capture
      )
      actual_md5sums = parse_md5sums(output)

      expect(actual_md5sums).to match_array(expected_md5sums)
    end
  end
end