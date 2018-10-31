#!/usr/bin/env ruby -S rspec

require 'spec_helper'
require 'semantic_puppet'
require 'puppet/pops/lookup/context'
puppetver = SemanticPuppet::Version.parse(Puppet.version)
requiredver = SemanticPuppet::Version.parse("4.10.0")

describe 'compliance_markup::hiera_backend' do
  skip 'requires function and test changes to handle incomplete LookupContext in rspec' do
    if (puppetver > requiredver)
      context "when key doesn't exist in the compliance map" do
        let(:hieradata) {"test_spec"}
        it 'should throw an error' do
          errored = false
          ex = nil
          begin
            result = subject.execute("compliance_markup::test::nonexistent", {}, Puppet::LookupContext.new('rp_env', 'compliance_markup'))
          rescue Exception => e
            ex = e
            errored = true
          end
          expect(errored).to eql(true)
        end
        it 'should throw a :no_such_key error' do
          errored = false
          ex = nil
          begin
            result = subject.execute("compliance_markup::test::nonexistent", {}, Puppet::LookupContext.new('rp_env', 'compliance_markup'))
          rescue Exception => e
            ex = e
            errored = true
          end
          expect(ex.to_s).to match(/no_such_key/)
        end
      end
      context "when key does exist in the compliance map" do
        let(:hieradata) {"test_spec"}
        it 'should not throw an error' do
          errored = false
          ex = nil
          begin
            result = subject.execute("compliance_markup::test::testvariable", {}, Puppet::LookupContext.new('rp_env', 'compliance_markup'))
          rescue Exception => e
            ex = e
            errored = true
          end
          expect(errored).to eql(false)
        end
        it 'should not throw a :no_such_key error' do
          errored = false
          ex = nil
          begin
            result = subject.execute("compliance_markup::test::testvariable", {}, Puppet::LookupContext.new('rp_env', 'compliance_markup'))
          rescue Exception => e
            ex = e
            errored = true
          end
          expect(ex.to_s).to_not match(/no_such_key/)
        end
        it 'should return "disa"' do
          errored = false
          ex = nil
          begin
            result = subject.execute("compliance_markup::test::testvariable", {}, Puppet::LookupContext.new('m'))
          rescue Exception => e
            ex = e
            errored = true
          end
          expect(ex.to_s).to_not match(/no_such_key/)
        end

        context "when key == compliance_markup::debug::hiera_backend_compile_time" do
          let(:hieradata) {"test_spec"}
          it 'should return an number' do
            errored = false
            ex = nil
            begin
              result = subject.execute("compliance_markup::debug::hiera_backend_compile_time", {}, nil)
            rescue Exception => e
              ex = e
              errored = true
            end
            puts "    completed in #{result} seconds"
            expect(result).to be_a(Float)
          end
        end
      end
    end
    context "when key == compliance_markup::test::confined_by_module" do
      let(:hieradata){ "test_spec" }
      it 'should return "confined"' do
        errored = false
        ex = nil
        begin
          result = subject.execute("compliance_markup::test::confined_by_module", {}, nil)
        rescue Exception => e
          ex = e
          errored = true
        end
        expect(result).to eql("confined")
      end
    end
    context "when key == compliance_markup::test::unconfined" do
      let(:hieradata){ "test_spec" }
      it 'should return "confined"' do
        errored = false
        ex = nil
        begin
          result = subject.execute("compliance_markup::test::unconfined", {}, nil)
        rescue Exception => e
          ex = e
          errored = true
        end
        expect(result).to eql("confined")
      end
    end
    context "when key == compliance_markup::test::confined_with_matching_fact" do
      let(:hieradata){ "test_spec" }
      it 'should return "confined"' do
        errored = false
        ex = nil
        begin
          result = subject.execute("compliance_markup::test::confined_with_matching_fact", {}, nil)
        rescue Exception => e
          ex = e
          errored = true
        end
        expect(result).to eql("confined")
      end
    end
    context "when key == compliance_markup::test::confined_with_not_matching_fact" do
      let(:hieradata){ "test_spec" }
      it 'should return "confined"' do
        errored = false
        ex = nil
        begin
          result = subject.execute("compliance_markup::test::confined_with_not_matching_fact", {}, nil)
        rescue Exception => e
          ex = e
          errored = true
        end
        expect(result).to_not eql("confined")
      end
    end
    context "when key == compliance_markup::test::confined_with_wrong_module_version" do
      let(:hieradata){ "test_spec" }
      it 'should not return "confined"' do
        errored = false
        ex = nil
        begin
          $pry_debug = true
          result = subject.execute("compliance_markup::test::confined_with_wrong_module_version", {}, nil)
        rescue Exception => e
          ex = e
          errored = true
        end
        expect(result).to_not eql("confined")
      end
    end
  end
end

