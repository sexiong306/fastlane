module Gym
  # Represents the Xcode project/workspace
  class Project
    # Path to the project/workspace
    attr_accessor :path

    attr_accessor :is_workspace

    def initialize(options)
      self.path = File.expand_path(options[:workspace] || options[:project])
      self.is_workspace = (options[:workspace].to_s.length > 0)

      if !path or !File.directory? path
        raise "Could not find project at path '#{path}'".red
      end
    end

    def workspace?
      self.is_workspace
    end

    # Get all available schemes in an array
    def schemes
      results = []
      output = raw_info.split("Schemes:").last.split(":").first

      if raw_info.include?("There are no schemes in workspace") or raw_info.include?("This project contains no schemes")
        return results
      end

      output.split("\n").each do |current|
        current = current.strip

        next if current.length == 0
        results << current
      end

      results
    end

    # Get all available configurations in an array
    def configurations
      results = []
      splitted = raw_info.split("Configurations:")
      return [] if splitted.count != 2 # probably a CocoaPods project

      output = splitted.last.split(":").first
      output.split("\n").each_with_index do |current, index|
        current = current.strip

        if current.length == 0
          next if index == 0
          break # as we want to break on the empty line
        end

        results << current
      end

      results
    end

    def app_name
      # WRAPPER_NAME: Example.app
      # WRAPPER_SUFFIX: .app
      name = build_settings(key: "WRAPPER_NAME")

      return name.gsub(build_settings(key: "WRAPPER_SUFFIX"), "") if name
      return "App" # default value
    end

    def mac?
      # Some projects have different values... we have to look for all of them
      return true if build_settings(key: "PLATFORM_NAME") == "macosx"
      return true if build_settings(key: "PLATFORM_DISPLAY_NAME") == "OS X"
      false
    end

    def ios?
      !mac?
    end

    #####################################################
    # @!group Raw Access
    #####################################################

    # Get the build settings for our project
    # this is used to properly get the DerivedData folder
    # @param [String] The key of which we want the value for (e.g. "PRODUCT_NAME")
    def build_settings(key: nil, optional: true)
      unless @build_settings
        # We also need to pass the workspace and scheme to this command
        command = "xcrun xcodebuild -showBuildSettings #{BuildCommandGenerator.project_path_array.join(' ')}"
        Helper.log.info command.yellow unless Gym.config[:silent]
        @build_settings = `#{command}`
      end

      begin
        result = @build_settings.split("\n").find { |c| c.include? key }
        return result.split(" = ").last
      rescue => ex
        return nil if optional # an optional value, we really don't care if something goes wrong

        Helper.log.error caller.join("\n\t")
        Helper.log.error "Could not fetch #{key} from project file: #{ex}"
      end

      nil
    end

    def raw_info
      # Examples:

      # Standard:
      #
      # Information about project "Example":
      #     Targets:
      #         Example
      #         ExampleUITests
      #
      #     Build Configurations:
      #         Debug
      #         Release
      #
      #     If no build configuration is specified and -scheme is not passed then "Release" is used.
      #
      #     Schemes:
      #         Example
      #         ExampleUITests

      # CococaPods
      #
      # Example.xcworkspace
      # Information about workspace "Example":
      #     Schemes:
      #         Example
      #         HexColors
      #         Pods-Example

      return @raw if @raw

      # Unfortunately since we pass the workspace we also get all the
      # schemes generated by CocoaPods

      options = BuildCommandGenerator.project_path_array.delete_if { |a| a.to_s.include? "scheme" }
      command = "xcrun xcodebuild -list #{options.join(' ')}"
      Helper.log.info command.yellow unless Gym.config[:silent]

      @raw = `#{command}`.to_s

      raise "Error parsing xcode file using `#{command}`".red if @raw.length == 0

      return @raw
    end
  end
end