#!/usr/bin/env ruby -S rspec
require 'spec_helper'

describe 'compliance_map' do
  context 'when called improperly' do
    it 'should accept a String or a Hash as the first parameter' do
      expect {
        subject.call([['string'],'string'])
      }.to raise_error(/First parameter must be .* String or Hash/)
    end

    context 'with a String as the first parameter' do
      it 'should only accept a String as the second parameter' do
        expect {
          subject.call(['string',['string']])
        }.to raise_error(/Second parameter must be .* String/)
      end

      it 'should only accept a String as the third parameter' do
        expect {
          subject.call(['string','string',['string']])
        }.to raise_error(/Third parameter must be .* String/)
      end

      it 'should require two parameters if any are given' do
        expect {
          subject.call(['string'])
        }.to raise_error(/at least two parameters/)
      end
    end
  end
end
