# frozen_string_literal: true

class DummyParserForDataTests
  def initialize(logger:, **procs)
    _logger = logger
    @procs = procs
    @events = {}
  end

  def parse_file(file)
    filename = File.join RSPEC_FIXTURES, 'network_rail', 'schedule', 'data', "#{file}.yaml"
    YAML.load(File.read(filename)).each do |event, data|
      if data.nil?
        @procs[event].call self
      else
        @procs[event].call self, *data
      end
    end
  end
end

describe RailFeeds::NetworkRail::Schedule::Data do
  before :each do
    expect(RailFeeds::NetworkRail::Schedule::Parser::CIF).to receive(:new) do |**args|
      DummyParserForDataTests.new(**args)
    end
  end
  subject do |example|
    data = described_class.new
    unless example.metadata[:skip_load_starting_data]
      # Populate with starting data
      filename = File.join RSPEC_FIXTURES, 'network_rail', 'schedule', 'data', 'starting.yaml'
      starting_data = YAML.load(File.read(filename))
      data.associations.clear
      data.tiplocs.clear
      data.trains.clear
      data.instance_exec(starting_data[:last_header]) { |h| @last_header = h }
      starting_data[:associations].each { |i| data.associations[i.hash] = i }
      starting_data[:trains].each do |uid, schedules|
        data.trains[uid] = []
        schedules.each do |i|
          data.trains[uid].push i
        end
      end
      starting_data[:tiplocs].each { |i| data.tiplocs[i.hash] = i }
    end
    data
  end

  describe '#load_cif_file' do
    describe 'Loads data' do
      context 'A full extract' do
        before(:each) { subject.load_cif_file('full') }

        describe 'Replaces data' do
          it 'Headers' do
            expect(subject.last_header.current_file_reference).to eq 'DFROC2Q'
          end

          it 'Tiplocs' do
            expect(subject.tiplocs.values.map(&:tiploc)).to eq ['1', '2', '3']
          end

          it 'Associations' do
            expect(subject.associations.values.map(&:main_location_suffix)).to eq ['a', 'b', 'c']
            expect(subject.associations.values.map(&:category)).to eq ['JJ', 'JJ', 'JJ']
          end

          it 'Trains' do
            expect(subject.trains.values.flatten.map(&:signalling_headcode)).to eq [
              '1A11',
              '2B22',
              '3C33'
            ]
          end
        end
      end

      context 'An update extract' do
        before(:each) do
          subject.load_cif_file 'full'
          subject.load_cif_file 'update'
        end

        describe 'Updates data' do
          it 'Headers' do
            expect(subject.last_header.current_file_reference).to eq 'DFROC1L'
          end

          it 'Tiplocs' do
            expect(subject.tiplocs.values.map(&:tiploc)).to eq ['1', '3a', '4', '5a']
          end

          it 'Associations' do
            expect(subject.associations.values.map(&:main_location_suffix)).to eq ['a', 'c', 'd', 'e']
            expect(subject.associations.values.map(&:category)).to eq ['JJ', 'VV', 'JJ', 'JJ']
          end

          it 'Trains' do
            expect(subject.trains.values.flatten.map(&:signalling_headcode)).to eq [
              '1A11',
              '3c33',
              '4D44',
              '5E55'
            ]
          end
        end
      end

      describe 'Errors on incorrect sequence', :skip_load_starting_data do
        it 'Update applied after a full extract' do
          subject.load_cif_file 'full'
          expect { subject.load_cif_file('update') }.to_not raise_error
        end

        it 'Update applied after previous update extract' do
          subject.load_cif_file 'full'
          subject.load_cif_file 'update'
          expect { subject.load_cif_file('update-next') }.to_not raise_error
        end

        it 'Update applied with a gap' do
          subject.load_cif_file 'full'
          subject.load_cif_file 'update'
          message = 'Missing update(s). Last applied update is "DFROC1L", ' \
                    'this update requires "DFROC1M" to be the previous applied update.'
          expect { subject.load_cif_file('update-gap') }.to raise_error ArgumentError, message
        end

        it 'Update applied too old update' do
          subject.load_cif_file 'full'
          subject.load_cif_file 'update'
          message = 'Update is too old, it is before the last applied update.'
          expect { subject.load_cif_file('update-old') }.to raise_error ArgumentError, message
        end

        it 'Update applied before a full extract' do
          message = 'Update can\'t be loaded before loading a full extract.'
          expect { subject.load_cif_file('update') }.to raise_error ArgumentError, message
        end
      end
    end
  end

  it '#generate_cif' do
    lines = []
    subject.load_cif_file 'full'
    subject.load_cif_file 'update'
    subject.generate_cif { |line| lines.push line }
    expect(lines).to eq([
      '/!! Start of file',
      '/!! Generated: 18/06/2018 19:45',
      'HD                    1806181945              F 190618180619                    ',
      'TI1                                                                             ',
      'TI3a                                                                            ',
      'TI4                                                                             ',
      'TI5a                                                                            ',
      'AAN                        1111100JJ 1      a T                                 ',
      'AAN                        1111100VV 3      c T                                 ',
      'AAN                        1111100JJ 4      d T                                 ',
      'AAN                        1111100JJ 5      e T                                 ',
      'BSN1                 1111100    1A11    1                                       ',
      'BX           N                                                                  ',
      'BSN3                 1111100    3c33    1                                       ',
      'BX           N                                                                  ',
      'BSN4                 1111100    4D44    1                                       ',
      'BX           N                                                                  ',
      'LO1       1111 1111      0 0             0                                      ',
      'CR2                                                                             ',
      'LI2            1111          1111                     0 0 0                     ',
      'LT3       2222 2222                                                             ',
      'BSN5                 1111100    5E55    1                                       ',
      'BX           N                                                                  ',
      'ZZ                                                                              ',
      '/!! End of file'
    ].map { |i| "#{i}\n" })
  end

  describe '#fetch_data' do
    let(:fetcher) { double RailFeeds::NetworkRail::Schedule::Fetcher }
    before :each do
      expect(RailFeeds::NetworkRail::Schedule::Fetcher)
        .to receive(:new).and_return(fetcher)
    end

    it 'Gets a full update if empty of data', :skip_load_starting_data do
      full_file = StringIO.new
      update_file = StringIO.new

      expect(fetcher).to receive(:fetch_all).and_yield(full_file).and_yield(update_file)
      expect(subject).to receive(:load_cif_file).with(full_file)
      expect(subject).to receive(:load_cif_file).with(update_file)

      subject.fetch_data
    end

    it 'Gets a full update if not updated in last week' do
      Timecop.freeze 2018, 6, 21
      full_file = StringIO.new
      update_file = StringIO.new

      expect(fetcher).to receive(:fetch_all).and_yield(full_file).and_yield(update_file)
      expect(subject).to receive(:load_cif_file).with(full_file)
      expect(subject).to receive(:load_cif_file).with(update_file)

      subject.fetch_data
    end

    it 'Just gets updates if updated in last week' do
      Timecop.freeze 2018, 6, 20
      update_file = StringIO.new

      expect(fetcher).to receive(:fetch_all_updates).and_yield(update_file)
      expect(subject).to receive(:load_cif_file).with(update_file)

      subject.fetch_data
    end
  end
end
