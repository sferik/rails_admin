require 'spec_helper'

RSpec.describe RailsAdmin::Config::Proxyable do
  class ProxyableTest
    include RailsAdmin::Config::Proxyable

    def boo
      sleep 0.15
      bindings[:foo]
    end

    def qux
      'foobar'
    end
  end

  let!(:proxyable_test) { ProxyableTest.new }
  subject do
    proxyable_test.bindings = {foo: 'bar'}
    proxyable_test
  end

  it 'proxies method calls to @object' do
    expect(subject.bindings).to eq foo: 'bar'
  end

  it 'preserves initially set @bindings' do
    expect(subject.with(foo: 'baz').tap(&:qux).bindings).to eq foo: 'bar'
  end

  context 'when a method is defined in Kernel' do
    before do
      Kernel.module_eval do
        def qux
          'quux'
        end
      end
    end

    after do
      Kernel.module_eval do
        undef qux
      end
    end

    it 'proxies calls for the method to @object' do
      expect(subject.qux).to eq 'foobar'
    end
  end

  describe 'with parallel execution' do
    it 'ensures thread-safety' do
      threads = Array.new(2) do |i|
        Thread.new do
          value = %w[a b][i]
          proxy = proxyable_test.with foo: value
          sleep i * 0.1
          expect(proxy.boo).to eq value
        end
      end
      threads.each(&:join)
    end
  end
end
