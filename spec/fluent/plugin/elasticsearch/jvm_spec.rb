require "spec_helper"

describe Fluent::Plugin::Elasticsearch::Jvm do
  it "has a version number" do
    expect(Fluent::Plugin::Elasticsearch::Jvm::VERSION).not_to be nil
  end

  it "does something useful" do
    expect(false).to eq(true)
  end
end
