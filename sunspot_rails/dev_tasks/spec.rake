require 'fileutils'

namespace :spec do
  def rails_app_path(version)
    File.join(File.dirname(__FILE__), "..", "tmp", "rails_#{version.gsub(".", "_")}_app")
  end

  def gemfile_path(version)
    File.join(File.dirname(__FILE__), "..", "gemfiles", "rails-#{version}")
  end

  def rails_template_path
    File.join(File.dirname(__FILE__), "..", "spec", "rails_template")
  end

  task :run_with_rails => [:set_gemfile, :generate_rails_app, :setup_rails_app, :run]

  task :set_gemfile do
    version = ENV['VERSION']

    ENV['BUNDLE_GEMFILE'] = gemfile_path(version)

    puts "Installing gems for Rails #{version}..."
    `bundle install #{ENV['BUNDLE_ARGS']}`
  end

  task :generate_rails_app do
    version = ENV['VERSION']
    app_path = rails_app_path(version)

    unless File.exist?(app_path)
      ENV['BUNDLE_GEMFILE'] = gemfile_path(version)
      rails_cmd = "rails _#{version}_"

      puts "Generating Rails #{version} application..."
      if version.start_with?("2")
        `#{rails_cmd} \"#{app_path}\" --force`
      elsif version.start_with?("3")
        `#{rails_cmd} new \"#{app_path}\" --force --skip-git --skip-javascript --skip-gemfile --skip-sprockets`
      end
    end
  end

  task :setup_rails_app do
    version = ENV['VERSION']
    app_path = rails_app_path(version)

    FileUtils.cp_r File.join(rails_template_path, "."), app_path
  end

  task :run do
    version = ENV['VERSION']

    ENV['BUNDLE_GEMFILE'] = gemfile_path(version)
    ENV['RAILS_ROOT']     = rails_app_path(version)

    spec_command = if version.start_with?("2")
                     "spec"
                   elsif version.start_with?("3")
                     "rspec"
                   end

    system "bundle exec #{spec_command} #{ENV['SPEC'] || 'spec/*_spec.rb'} --color"
  end
end

def rails_all_versions
  versions = []
  Dir.glob(File.join(File.dirname(__FILE__), "..", "gemfiles", "rails-*")).each do |gemfile|
    if !gemfile.end_with?(".lock") && gemfile =~ /rails-([0-9.]+)/
      versions << $1
    end
  end

  versions
end

def reenable_spec_tasks
  Rake::Task.tasks.each do |task|
    if task.name =~ /spec:/
      task.reenable
    end
  end
end

desc 'Run spec suite in all Rails versions'
task :spec do
  versions = if ENV['VERSIONS']
               ENV['VERSIONS'].split(",")
             else
               rails_all_versions
             end

  versions.each do |version|
    puts "Running specs against Rails #{version}..."

    ENV['VERSION'] = version
    reenable_spec_tasks
    Rake::Task['spec:run_with_rails'].invoke
  end
end
