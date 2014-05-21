require 'spec_helper'

describe AnalizoMetricCollector do
  describe 'methods' do
    describe 'name' do
      it 'should return Analizo' do
        subject.name.should eq("Analizo")
      end
    end

    describe 'metric_list' do
      context 'when the collector is installed on the computer' do
        it "should return all the collector's metrics not parsed" do
          subject.metric_list.should be_a(String)
        end
      end

      pending 'is it better to return nil or to raise an exception?' do
        context 'when the collector is not installed on the computer' do
          it 'should return something' do
          end
        end
      end
    end

    describe 'parse_supported_metrics' do
      context 'with a valid metrics list' do
        let!(:metric) { FactoryGirl.build(:analizo_native_metric) }
        let!(:acc) { FactoryGirl.build(:analizo_native_metric, name: 'Afferent Connections per Class (used to calculate COF - Coupling Factor)', compound: false, scope: :CLASS) }
        before :each do
          subject.expects(:metric_list).at_least_once.returns(YAML.load_file('spec/factories/analizo_metric_collector.yml')["list"])
          NativeMetric.expects(:new).with(metric.name, metric.scope.type, metric.languages).returns(metric)
          NativeMetric.expects(:new).with(acc.name, acc.scope, acc.languages).returns(acc)
        end
        it 'should return a hash in the format code => metric' do
          ret = subject.parse_supported_metrics
          ret["acc"].should eq(acc)
          ret["total_abstract_classes"].should eq(metric)
        end
      end
    end

    describe 'wanted_metrics=' do
      let(:native_metric) { FactoryGirl.build(:analizo_native_metric) }
      let(:wanted_metrics_list) { ["total_abstract_classes", "amloc"] }
      context 'list of supported metrics have at least one wanted metric' do
        let!(:response) { {"total_abstract_classes" => native_metric} }

        before :each do
          subject.expects(:supported_metrics).returns(response)
        end

        it 'should return a hash with the wanted metrics' do
          subject.wanted_metrics = wanted_metrics_list
          subject.wanted_metrics.should eq(response)
        end
      end

      context "list of supported metrics don't have any wanted metric" do
        let!(:total_modules) { FactoryGirl.build(:analizo_native_metric, name: "Total Number of Modules") }

        before :each do
          subject.expects(:supported_metrics).returns({"total_modules" => total_modules})
        end

        it 'should return an empty hash' do
          subject.wanted_metrics = wanted_metrics_list
          subject.wanted_metrics.should eq({})
        end
      end
    end

    describe 'execute_analizo' do
      context 'when the collector is installed on the computer and the absolute_path is valid' do
        let(:absolute_path) { "app/models/metric.rb" }
        it "should return all the metric results not parsed" do
          subject.execute_analizo(absolute_path).should be_a(String)
        end
      end

      pending 'is it better to return nil or to raise an exception?' do
        context 'when the collector is not installed on the computer' do
          it 'should return something' do
          end
        end

        context 'when the absolute_path is wrong' do
          it 'should return something' do
          end
        end
      end
    end

    describe 'new_metric_result' do
      let(:metric) { FactoryGirl.build(:analizo_native_metric) }
      let(:value) { 2.0 }
      let(:code) { "code" }
      let(:wanted_metric) { {"code" => metric} }

      before :each do
        subject.expects(:wanted_metrics).returns(wanted_metric)
      end

      it 'should create a new metric result' do
        metric_result = subject.new_metric_result(code, value)
        metric_result.value.should eq(value)
        metric_result.metric.should eq(metric)
      end
    end

    describe 'new_module_result' do
      context 'when the result map contains only global values' do
        let(:result_map) { {"total_abstract_classes" => "10"} }
        let!(:kalibro_module) { FactoryGirl.build(:kalibro_module) }
        before :each do
          KalibroModule.expects(:new).with({granularity: kalibro_module.granularity.type, name: []}).returns(kalibro_module)
        end

        it 'should create a module with software modularity' do
          module_result = subject.new_module_result(result_map)
          module_result.kalibro_module.should eq(kalibro_module)
        end
      end

      context 'when the result map contains a module result' do
        let(:result_map) { {"_filename"=>["Class.rb"], "_module"=>"FirstModule::SecondModule::FinalModule", "acc"=>0} }
        let!(:kalibro_module) { FactoryGirl.build(:kalibro_module, granularity: FactoryGirl.build(:class_granularity)) }
        before :each do
          KalibroModule.expects(:new).
          with({granularity: kalibro_module.granularity.type, name: ["FirstModule", "SecondModule", "FinalModule"]}).
          returns(kalibro_module)
        end

        it 'should create a module with class modularity' do
          module_result = subject.new_module_result(result_map)
          module_result.kalibro_module.should eq(kalibro_module)
        end
      end
    end

    describe 'parse_single_result' do
      let(:metric) { FactoryGirl.build(:analizo_native_metric) }
      let!(:wanted_metric) { {"total_abstract_classes" => metric} }
      before :each do
        subject.expects(:wanted_metrics).at_least_once.returns(wanted_metric)
      end

      context 'when there is wanted metrics' do
        let!(:module_result) { FactoryGirl.build(:module_result_class_granularity) }
        let!(:result_map) { {"total_abstract_classes" => "10"} }
        before :each do
          subject.expects(:new_module_result).with(result_map).returns(module_result)
        end

        it 'should return a module result with metric results' do
          parsed_single_result = subject.parse_single_result(result_map)
          parsed_single_result.should eq(module_result)
          #parsed_single_result.metric_results.first.should eq(metric_result)
        end
      end

      context 'when the there is not wanted metrics' do
        let!(:module_result) { FactoryGirl.build(:module_result) }
        let!(:result_map) { {"_filename"=>["Class.rb"], "_module"=>"FirstModule::SecondModule::FinalModule", "acc"=>0} }
        before :each do
          subject.expects(:new_module_result).with(result_map).returns(module_result)
        end
        it 'should return a module result with no metric results' do
          subject.parse_single_result(result_map).should eq(module_result)
        end
      end
    end
  end
end