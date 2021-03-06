require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "template_runner" do
  before(:each) do
    setup_template_runner
  end
  describe "slicehost" do
    before(:each) do
      @runner.on_command(:run, "slicehost-slice list") do
        <<-EOS.gsub(/^          /, '')
        + mocra-primary (123.123.123.123)
        + mocra-secondary (65.65.65.65)
        EOS
      end
    end
    it { @runner.slice_names.should == %w[mocra-primary mocra-secondary]}
  end
  describe "no authentication" do
    describe "run template for public repo" do
      before(:each) do
        @runner.highline.should_receive(:choose).exactly(2).and_return("none", "mocra-primary", "public")
        @runner.on_command(:run, "slicehost-slice list") do
          <<-EOS.gsub(/^          /, '')
          + mocra-primary (123.123.123.123)
          + mocra-secondary (65.65.65.65)
          EOS
        end
        @runner.on_command(:run, "git config --get github.user") { "github_person\n" }

        @runner.run_template
        @log = @runner.full_log
      end
      
      it "should check various things" do
        @log.should =~ %r{executing  slicehost-dns add_cname mocra.com rails-templates mocra-primary}
        @log.should_not =~ %r{executing  twitter register_oauth}
        @runner.files['config/twitter_auth.yml'].should be_nil
        @runner.files['config/initializers/mailer.rb'].should be_nil
        @runner.files['config/mailer.yml'].should be_nil
        @runner.files['app/views/users/new.html.erb'].should be_nil
        @runner.files['app/controllers/application_controller.rb'].should_not =~ /^\s+include AuthenticatedSystem$/
        @log.should =~ %r{file  config/deploy.rb}
        @log.should =~ %r{executing  cap deploy:setup}
        @log.should =~ %r{executing  cap deploy:cold}
      end
      it "should create and use a public repository" do
        @runner.files['config/deploy.rb'].should =~ %r{git://github.com/github_person/}
        @log.should =~ %r{executing  github create-from-local}
        @log.should_not =~ %r{executing  github create-from-local\s+--private}
      end
    end
  end
  describe "restful_authentication" do
    describe "run template for private repo" do
      before(:each) do
        @runner.highline.should_receive(:choose).exactly(2).and_return("restful_authentication", "mocra-primary", "private")
        @runner.on_command(:run, "slicehost-slice list") do
          <<-EOS.gsub(/^          /, '')
          + mocra-primary (123.123.123.123)
          + mocra-secondary (65.65.65.65)
          EOS
        end
        @runner.on_command(:run, "git config --get github.user") { "github_person\n" }

        @runner.run_template
        @log = @runner.full_log
      end
      
      it "should check various things" do
        @log.should =~ %r{executing  slicehost-dns add_cname mocra.com rails-templates mocra-primary}
        @log.should_not =~ %r{executing  twitter register_oauth}
        @runner.files['config/twitter_auth.yml'].should be_nil
        @runner.files['config/initializers/mailer.rb'].should_not be_nil
        @runner.files['config/mailer.yml'].should_not be_nil
        @runner.files['app/views/users/new.html.erb'].should =~ /mailer.yml/
        @runner.files['app/controllers/application_controller.rb'].should =~ /^\s+include AuthenticatedSystem$/
        @log.should =~ %r{file  config/deploy.rb}
        @log.should =~ %r{executing  cap deploy:setup}
        @log.should =~ %r{executing  cap deploy:cold}
      end
      it "should create and use a private repository" do
        @runner.files['config/deploy.rb'].should =~ %r{git@github.com:github_person/}
        @log.should =~ %r{executing  github create-from-local}
      end
    end
  end
  describe "twitter" do
    describe "register_oauth" do
      describe "success" do
        before(:each) do
          @message = <<-EOS.gsub(/^        /, '')
          Nice! You've registered your application successfully.
          Consumer key:    CONSUMERKEY
          Consumer secret: CONSUMERSECRET
          EOS
        end
        describe "and parse keys" do
          before(:each) do
            @keys = @runner.parse_keys(@message)
          end
          it { @keys[:key].should == "CONSUMERKEY" }
          it { @keys[:secret].should == "CONSUMERSECRET" }
        end
      end
      describe "error" do
        before(:each) do
          @message = <<-EOS.gsub(/^        /, '')
          Unable to register this application. Check your registration settings.
          * Name has already been taken
          EOS
        end
        describe "and parse keys" do
          before(:each) do
            @keys = @runner.parse_keys(@message)
          end
          it { @keys[:key].should == "TWITTER_CONSUMERKEY" }
          it { @keys[:secret].should == "TWITTER_CONSUMERSECRET" }
        end
      end
    end
    describe "run template for read/write twitter registration" do
      before(:each) do
        @runner.highline.should_receive(:choose).exactly(4).
          and_return("twitter_auth", "mocra-primary", "drnic", "read-write", "public")
        @runner.on_command(:run, "twitter register_oauth drnic 'Rails Templates' http://rails-templates.mocra.com 'This is a cool app' organization='Mocra' organization_url=http://mocra.com --readwrite") do
          <<-EOS.gsub(/^          /, '')
          Nice! You've registered your application successfully.
          Consumer key:    CONSUMERKEY
          Consumer secret: CONSUMERSECRET
          EOS
        end
        @runner.on_command(:run, "slicehost-slice list") do
          <<-EOS.gsub(/^          /, '')
          + mocra-primary (123.123.123.123)
          + mocra-secondary (65.65.65.65)
          EOS
        end
        @runner.on_command(:run, "git config --get github.user") { "github_person\n" }

        @runner.run_template
        @log = @runner.full_log
      end
      
      it "should check various things" do
        @log.should =~ %r{executing  slicehost-dns add_cname mocra.com rails-templates mocra-primary}
        @runner.files['config/twitter_auth.yml'].should_not be_nil
        @runner.files['config/twitter_auth.yml'].should =~ %r{oauth_consumer_key: CONSUMERKEY}
        @runner.files['config/twitter_auth.yml'].should =~ %r{oauth_consumer_secret: CONSUMERSECRET}
        @log.should =~ %r{file  config/deploy.rb}
        @log.should =~ %r{executing  cap deploy:setup}
        @log.should =~ %r{executing  cap deploy:cold}
      end
      it "should be read-write access to twitter" do
        @log.should =~ %r{executing  twitter register_oauth drnic 'Rails Templates' http://rails-templates.mocra.com 'This is a cool app' organization='Mocra' organization_url=http://mocra.com --readwrite}
      end
    end

    describe "run template for read-only twitter registration" do
      before(:each) do
        @runner.highline.should_receive(:choose).exactly(4).
          and_return("twitter_auth", "mocra-primary", "drnic", "read-only", "public")
        @runner.on_command(:run, "twitter register_oauth drnic 'Rails Templates' http://rails-templates.mocra.com 'This is a cool app' organization='Mocra' organization_url=http://mocra.com") do
          <<-EOS.gsub(/^          /, '')
          Nice! You've registered your application successfully.
          Consumer key:    CONSUMERKEY
          Consumer secret: CONSUMERSECRET
          EOS
        end
        @runner.on_command(:run, "slicehost-slice list") do
          <<-EOS.gsub(/^          /, '')
          + mocra-primary (123.123.123.123)
          + mocra-secondary (65.65.65.65)
          EOS
        end
        @runner.on_command(:run, "git config --get github.user") { "github_person\n" }

        @runner.run_template
        @log = @runner.full_log
      end
      
      it "should be read-only access to twitter" do
        @log.should =~ %r{executing  twitter register_oauth drnic 'Rails Templates' http://rails-templates.mocra.com 'This is a cool app' organization='Mocra' organization_url=http://mocra.com}
      end
    end
  end
end
