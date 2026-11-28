# load the helper module on top of the engine, then the test
begin
  eval(File.read(ENV["RH"]), TOPLEVEL_BINDING, "RH")
rescue Exception => e
  STDERR.puts "RH load: #{e.class} #{e.message[0,200]}"
end
eval(File.read(File.join(__dir__, ENV["T"] || "titania.rb")), TOPLEVEL_BINDING, "test")
