class Filebeat < Formula
  desc "File harvester to ship log files to Elasticsearch or Logstash"
  homepage "https://www.elastic.co/products/beats/filebeat"
  url "https://github.com/elastic/beats/archive/v6.2.1.tar.gz"
  sha256 "7fc935b65469acc728653c89ef7b8541db4c5dafdbb1459822f0c215d58d30e6"
  head "https://github.com/elastic/beats.git"

  bottle do
    cellar :any_skip_relocation
    sha256 "566a60c9e08f2ecc2e6eddcb44912891a11ba0c53d20e1af8b8f8accd8b09f01" => :high_sierra
    sha256 "0a98d183faca3dee7345d095da08deb0346418de2606007f0c2c362c2cb25e4c" => :sierra
    sha256 "1bb2a9f066a443bf3f0f88654f7a32bb1c64085c05c854edfe7b5e11018074aa" => :el_capitan
  end

  depends_on "go" => :build

  def install
    gopath = buildpath/"gopath"
    (gopath/"src/github.com/elastic/beats").install Dir["{*,.git,.gitignore}"]

    ENV["GOPATH"] = gopath

    cd gopath/"src/github.com/elastic/beats/filebeat" do
      system "make"
      system "make", "modules"
      libexec.install "filebeat"
      (prefix/"module").install Dir["_meta/module.generated/*"]
      (etc/"filebeat").install Dir["filebeat.*"]
    end

    prefix.install_metafiles gopath/"src/github.com/elastic/beats"

    (bin/"filebeat").write <<~EOS
      #!/bin/sh
      exec #{libexec}/filebeat -path.config #{etc}/filebeat -path.home #{prefix} -path.logs #{var}/log/filebeat -path.data #{var}/filebeat $@
    EOS
  end

  plist_options :manual => "filebeat"

  def plist; <<~EOS
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
      <dict>
        <key>Label</key>
        <string>#{plist_name}</string>
        <key>Program</key>
        <string>#{opt_bin}/filebeat</string>
        <key>RunAtLoad</key>
        <true/>
      </dict>
    </plist>
  EOS
  end

  test do
    log_file = testpath/"test.log"
    touch log_file

    (testpath/"filebeat.yml").write <<~EOS
      filebeat:
        prospectors:
          -
            paths:
              - #{log_file}
            scan_frequency: 0.1s
      output:
        file:
          path: #{testpath}
    EOS

    (testpath/"log").mkpath
    (testpath/"data").mkpath

    filebeat_pid = fork { exec "#{bin}/filebeat -c #{testpath}/filebeat.yml -path.config #{testpath}/filebeat -path.home=#{testpath} -path.logs #{testpath}/log -path.data #{testpath}" }
    begin
      sleep 1
      log_file.append_lines "foo bar baz"
      sleep 5

      assert_predicate testpath/"filebeat", :exist?
    ensure
      Process.kill("TERM", filebeat_pid)
    end
  end
end
