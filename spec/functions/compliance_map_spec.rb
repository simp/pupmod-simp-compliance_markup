#!/usr/bin/env ruby -S rspec
require 'spec_helper'

describe 'compliance_map' do
  context 'when called improperly' do
    it 'should accept a String or a Hash as the first parameter' do
      is_expected.to run.with_params(['string'], 'string').and_raise_error(/First parameter must be .* String or Hash/)
    end

    context 'with a String as the first parameter' do
      it 'should only accept a String as the second parameter' do
        is_expected.to run.with_params('string', ['string']).and_raise_error(/Second parameter must be .* String/)
      end

      it 'should only accept a String as the third parameter' do
        is_expected.to run.with_params('string', 'string', ['string']).and_raise_error(/Third parameter must be .* String/)
      end

      it 'should require two parameters if any are given' do
        is_expected.to run.with_params('string').and_raise_error(/at least two parameters/)
      end
    end
  end
end
