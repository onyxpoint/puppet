#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

property = Puppet::Type.type(:file).attrclass(:mode)

describe property do
    before do
        @resource = stub 'resource', :line => "foo", :file => "bar"
        @mode = property.new :resource => @resource
    end

    it "should have a method for converting symbolic modes to octal modes" do
        @mode.must respond_to(:sym2oct)
    end
    it "should be able to apply three digit numeric octal modes" do
        @mode.sym2oct("777",Integer("0640")).should == Integer("0640")
    end
    it "should be able to apply additive symbolic user modes" do
        @mode.sym2oct("640","u+x").should == Integer("0740")
    end
    it "should be able to apply subtractive symbolic user modes" do
        @mode.sym2oct("640","u-w").should == Integer("0440")
    end
    it "should be able to apply equality symbolic user modes" do
        @mode.sym2oct("640","u=r").should == Integer("0440")
    end
    it "should be able to apply referential equality symbolic user modes" do
        @mode.sym2oct("640","u=g").should == Integer("0440")
    end
    it "should be able to apply additive symbolic group modes" do
        @mode.sym2oct("640","g+x").should == Integer("0650")
    end
    it "should be able to apply subtractive symbolic group modes" do
        @mode.sym2oct("640","g-r").should == Integer("0600")
    end
    it "should be able to apply equality symbolic group modes" do
        @mode.sym2oct("640","g=rwx").should == Integer("0670")
    end
    it "should be able to apply referential equality symbolic group modes" do
        @mode.sym2oct("640","g=o").should == Integer("0600")
    end
    it "should be able to apply additive symbolic other modes" do
        @mode.sym2oct("640","o+rx").should == Integer("0645")
    end
    it "should be able to apply subtractive symbolic other modes" do
        @mode.sym2oct("647","o-rx").should == Integer("0642")
    end
    it "should be able to apply equality symbolic other modes" do
        @mode.sym2oct("647","o-rx").should == Integer("0642")
    end
    it "should be able to apply referential equality symbolic other modes" do
        @mode.sym2oct("647","o=u").should == Integer("0646")
    end
    it "should be able to apply multi-part modes" do
        @mode.sym2oct("640","o=u,g=o,u-w").should == Integer("0466")
    end
    it "should not be able to apply invalid modes" do
        @mode.sym2oct("640","go-write-a-letter").should == Integer("0640")
    end
end
