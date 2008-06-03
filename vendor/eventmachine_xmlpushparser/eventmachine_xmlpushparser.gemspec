
spec = Gem::Specification.new do |s|
    s.name              = "eventmachine_xmlpushparser"
    s.version           = "0.0.1"
    s.summary           = "EventMachine XML Push Parser"
    s.platform          = Gem::Platform::RUBY

    s.has_rdoc          = true
    s.rdoc_options      = %w(--title EventMachine_XMLPushParser --main README --line-numbers)
    # Include the Rakefile so users can run our test suite.
    s.extra_rdoc_files = ["README", "RELEASE_NOTES", "COPYING", "Rakefile"]

    # Exclude rdocs and any compiled shared objects which may be present.
    s.files             = FileList["{ext,lib,test}/**/*"].exclude(/rdoc|\.so\Z/).to_a

    s.require_paths     = ["lib"]
    s.extensions        = "ext/extconf.rb"

    s.author            = "Francis Cianfrocca"
    s.email             = "garbagecat10@gmail.com"
    s.homepage          = "http://www.eventmachine.com"


    description = []
    File.open("README") do |file|
	file.each do |line|
	    line.chomp!
	    break if line.empty?
	    description << "#{line.gsub(/\[\d\]/, '')}"
	    end
	end
    s.description = description[1..-1].join(" ")
end


