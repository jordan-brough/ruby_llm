# frozen_string_literal: true

require 'spec_helper'
require 'googleauth'

RSpec.describe RubyLLM::Providers::VertexAI do
  subject(:provider) { described_class.new(config) }

  let(:config) do
    instance_double(
      RubyLLM::Configuration,
      request_timeout: 300,
      max_retries: 3,
      retry_interval: 0.1,
      retry_interval_randomness: 0.5,
      retry_backoff_factor: 2,
      http_proxy: nil,
      vertexai_location: location,
      vertexai_project_id: 'test-project',
      vertexai_credentials_json: credentials_json
    )
  end

  let(:credentials_json) { nil }

  describe '#api_base' do
    context 'when location is global' do
      let(:location) { 'global' }

      it 'uses the correct api_base without location prefix' do
        expect(provider.api_base).to eq('https://aiplatform.googleapis.com/v1beta1')
      end
    end

    context 'when location is not global' do
      let(:location) { 'us-central1' }

      it 'uses the correct api_base with location prefix' do
        expect(provider.api_base).to eq('https://us-central1-aiplatform.googleapis.com/v1beta1')
      end
    end
  end

  describe '#headers' do
    let(:location) { 'us-central1' }
    let(:mock_creds) { instance_double(Google::Auth::ServiceAccountCredentials) }
    let(:cassette) { instance_double('VCR::Cassette', recording?: true) }

    before do
      allow(VCR).to receive(:current_cassette).and_return(cassette)
      allow(mock_creds).to receive(:apply).with({}).and_return({ 'Authorization' => 'Bearer test-sa-token' })
    end

    context 'when vertexai_credentials_json is set' do
      let(:credentials_json) { '{"type":"service_account","project_id":"test"}' }

      it 'uses ServiceAccountCredentials with the JSON string' do
        allow(Google::Auth::ServiceAccountCredentials).to receive(:make_creds).and_return(mock_creds)

        expect(provider.headers).to eq({ 'Authorization' => 'Bearer test-sa-token' })
        expect(Google::Auth::ServiceAccountCredentials).to have_received(:make_creds).with(
          json_key_io: an_instance_of(StringIO),
          scope: [
            'https://www.googleapis.com/auth/cloud-platform',
            'https://www.googleapis.com/auth/generative-language.retriever'
          ]
        )
      end
    end

    context 'when vertexai_credentials_json is nil' do
      let(:credentials_json) { nil }

      it 'falls back to Application Default Credentials' do
        allow(Google::Auth).to receive(:get_application_default).and_return(mock_creds)

        expect(provider.headers).to eq({ 'Authorization' => 'Bearer test-sa-token' })
        expect(Google::Auth).to have_received(:get_application_default).with(
          scope: [
            'https://www.googleapis.com/auth/cloud-platform',
            'https://www.googleapis.com/auth/generative-language.retriever'
          ]
        )
      end
    end
  end
end
