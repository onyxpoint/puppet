#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

property = Puppet::Type.type(:file).attrclass(:mode)

describe property do
    before do
        @resource = stub 'resource', :line => "foo", :file => "bar"
        @resource.stubs(:[]).returns "foo"
        @resource.stubs(:[]).with(:path).returns "/my/file"
        @mode = property.new :resource => @resource
    end

    it "should have a method for converting symbolic modes to octal modes" do
        @mode.must respond_to(:sym2oct)
    end

    it "should be able to apply numeric octal modes"
    it "should be able to apply additive symbolic user modes"
    it "should be able to apply subtractive symbolic user modes"
    it "should be able to apply equality symbolic user modes"
    it "should be able to apply referential equality symbolic user modes"
    it "should be able to apply additive symbolic group modes"
    it "should be able to apply subtractive symbolic group modes"
    it "should be able to apply equality symbolic group modes"
    it "should be able to apply referential equality symbolic group modes"
    it "should be able to apply additive symbolic other modes"
    it "should be able to apply subtractive symbolic other modes"
    it "should be able to apply equality symbolic other modes"
    it "should be able to apply referential equality symbolic other modes"
    it "should be able to apply multi-part modes"
    it "should not be able to apply invalid modes"
end
