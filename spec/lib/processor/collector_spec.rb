require 'rails_helper'
require 'metric_collector'
require 'processor'

describe Processor::Collector do
  pending 'kalibro client integration' do
    describe 'methods' do
      describe 'task' do
        let(:configuration) { FactoryGirl.build(:configuration) }
        let!(:code_dir) { "/tmp/test" }
        let!(:repository) { FactoryGirl.build(:repository, scm_type: "GIT", configuration: configuration, code_directory: code_dir) }
        let!(:processing) { FactoryGirl.build(:processing, repository: repository) }
        let!(:metric_configuration) { FactoryGirl.build(:metric_configuration) }
        let!(:context) { FactoryGirl.build(:context, repository: repository, processing: processing) }

        before :each do
          context.processing.expects(:reload)
          context.expects(:native_metrics).returns({metric_configuration.metric_collector_name => [metric_configuration]})
          MetricCollector::Native::Analizo.any_instance.expects(:collect_metrics).with(code_dir, [metric_configuration], processing)
        end

        context 'without producing module_results' do
          it 'is expected to raise an EmptyModuleResultsError' do
            expect { Processor::Collector.task(context) }.to raise_error(Errors::EmptyModuleResultsError)
          end
        end

        context 'producing module_results' do
          before :each do
            context.processing.expects(:module_results).returns([mock("module_result")])
          end
          it 'is expected to accomplish the collecting state of a process successfully' do
            Processor::Collector.task(context)
          end
        end
      end

      describe 'state' do
        it 'is expected to return "COLLECTING"' do
          expect(Processor::Collector.state).to eq("COLLECTING")
        end
      end
    end
  end
end
