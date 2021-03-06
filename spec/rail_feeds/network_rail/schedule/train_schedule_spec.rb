# frozen_string_literal: true

describe RailFeeds::NetworkRail::Schedule::TrainSchedule do
  let(:line_basic) do
    'BSNa123450102030405061010101bscciiii2222111111111 PPPtttt333ooooooSFR catebran P'
  end
  let(:line_extra) do
    'BX    11111TTY                                                                  '
  end
  let :json do
    file = File.join RSPEC_FIXTURES, 'network_rail', 'schedule', 'train_schedule', 'json-data.yaml'
    YAML.load(File.read(file)).to_json
  end

  subject do
    described_class.new(
      uid: 'a12345',
      start_date: Date.new(2001, 2, 3),
      end_date: Date.new(2004, 5, 6),
      days: [true, false, true, false, true, false, true],
      bank_holiday_running: 'b',
      status: 's',
      category: 'cc',
      signalling_headcode: 'iiii',
      reservation_headcode: 2222,
      service_code: 11111111,
      power_type: 'PPP',
      timing_load: 'tttt',
      speed: 333,
      operating_characteristics: 'oooooo',
      seating_class: 'S',
      sleeping_class: 'F',
      reservations: 'R',
      catering: 'cate',
      branding: 'bran',
      stp_indicator: :permanent,
      uic: 11111,
      atoc: 'TT',
      applicable_timetable: true
    )
  end

  it '::from_json' do
    subject = described_class.from_json json
    expect(subject.uid).to eq 'W20309'
    expect(subject.category).to eq 'OO'
    expect(subject.status).to eq 'S'
    expect(subject.reservation_headcode).to eq 1234
    expect(subject.signalling_headcode).to eq '2U10'
    expect(subject.service_code).to eq '24627006'
    expect(subject.start_date).to eq Date.new(2018, 5, 21)
    expect(subject.end_date).to eq Date.new(2018, 12, 7)
    expect(subject.days).to eq [true, true, true, true, true, false, false]
    expect(subject.bank_holiday_running).to eq 'B'
    expect(subject.power_type).to eq 'EMU'
    expect(subject.timing_load).to eq '483'
    expect(subject.speed).to eq 45
    expect(subject.operating_characteristics).to eq 'OPER-CHAR'
    expect(subject.seating_class).to eq 'S'
    expect(subject.sleeping_class).to eq 'B'
    expect(subject.reservations).to eq 'R'
    expect(subject.catering).to eq 'C'
    expect(subject.branding).to eq 'Br'
    expect(subject.uic).to eq 12345
    expect(subject.atoc).to eq 'IL'
    expect(subject.applicable_timetable).to eq true
    expect(subject.stp_indicator).to eq :permanent
    expect(subject.journey.size).to eq 3
  end

  describe '#update_from_line' do
    it 'Standard information' do
      subject.update_from_cif line_basic
      expect(subject.uid).to eq 'a12345'
      expect(subject.start_date).to eq Date.new(2001, 2, 3)
      expect(subject.end_date).to eq Date.new(2004, 5, 6)
      expect(subject.days).to eq [true, false, true, false, true, false, true]
      expect(subject.bank_holiday_running).to eq 'b'
      expect(subject.status).to eq 's'
      expect(subject.category).to eq 'cc'
      expect(subject.signalling_headcode).to eq 'iiii'
      expect(subject.reservation_headcode).to eq 2222
      expect(subject.service_code).to eq 11111111
      expect(subject.power_type).to eq 'PPP'
      expect(subject.timing_load).to eq 'tttt'
      expect(subject.speed).to eq 333
      expect(subject.operating_characteristics).to eq 'oooooo'
      expect(subject.seating_class).to eq 'S'
      expect(subject.sleeping_class).to eq 'F'
      expect(subject.reservations).to eq 'R'
      expect(subject.catering).to eq 'cate'
      expect(subject.branding).to eq 'bran'
      expect(subject.stp_indicator).to eq :permanent
    end

    it 'Extra information' do
      subject.update_from_cif line_extra
      expect(subject.uic).to eq 11111
      expect(subject.atoc).to eq 'TT'
      expect(subject.applicable_timetable).to eq true
    end

    it 'Origin location' do
      line = 'LO'
      expect(RailFeeds::NetworkRail::Schedule::TrainSchedule::Location)
        .to receive(:from_cif).with(line).and_return(:origin)
      subject.update_from_cif line
      expect(subject.journey).to eq [:origin]
    end

    it 'Intermediate location' do
      line = 'LI'
      expect(RailFeeds::NetworkRail::Schedule::TrainSchedule::Location)
        .to receive(:from_cif).with(line).and_return(:intermediate)
      subject.update_from_cif line
      expect(subject.journey).to eq [:intermediate]
    end

    it 'Terminating location' do
      line = 'LT'
      expect(RailFeeds::NetworkRail::Schedule::TrainSchedule::Location)
        .to receive(:from_cif).with(line).and_return(:terminating)
      subject.update_from_cif line
      expect(subject.journey).to eq [:terminating]
    end

    it 'Series of locations' do
      expect(RailFeeds::NetworkRail::Schedule::TrainSchedule::Location)
        .to receive(:from_cif).with('LO').and_return(:origin)
      expect(RailFeeds::NetworkRail::Schedule::TrainSchedule::Location)
        .to receive(:from_cif).with('LI').and_return(:intermediate)
      expect(RailFeeds::NetworkRail::Schedule::TrainSchedule::Location)
        .to receive(:from_cif).with('LT').and_return(:terminating)
      subject.update_from_cif 'LO'
      subject.update_from_cif 'LI'
      subject.update_from_cif 'LT'
      expect(subject.journey).to eq %i[origin intermediate terminating]
    end

    it 'Change en route' do
      line = 'CR'
      expect(RailFeeds::NetworkRail::Schedule::TrainSchedule::ChangeEnRoute)
        .to receive(:from_cif).with(line).and_return(:change)
      subject.update_from_cif line
      expect(subject.journey).to eq [:change]
    end

    it '#journey contains locations and change en routes' do
      expect(RailFeeds::NetworkRail::Schedule::TrainSchedule::Location)
        .to receive(:from_cif).with('LO').and_return(:origin)
      expect(RailFeeds::NetworkRail::Schedule::TrainSchedule::Location)
        .to receive(:from_cif).with('LI').and_return(:intermediate)
      expect(RailFeeds::NetworkRail::Schedule::TrainSchedule::Location)
        .to receive(:from_cif).with('LT').and_return(:terminating)
      expect(RailFeeds::NetworkRail::Schedule::TrainSchedule::ChangeEnRoute)
        .to receive(:from_cif).with('CR').and_return(:change)
      subject.update_from_cif 'LO'
      subject.update_from_cif 'CR'
      subject.update_from_cif 'LI'
      subject.update_from_cif 'LT'
      expect(subject.journey).to eq %i[origin change intermediate terminating]
    end

    it 'Fails on bad line' do
      line = 'bad line'
      expect { subject.update_from_cif line }
        .to raise_error ArgumentError, 'Improper line type ba: bad line'
    end

    it 'Delete line' do
      line = 'BSDC77714180526                                                                P'
      subject.update_from_cif line
      expect(subject.uid).to eq 'C77714'
      expect(subject.start_date).to eq Date.new(2018, 5, 26)
      expect(subject.end_date).to be_nil
      expect(subject.days).to eq [false, false, false, false, false, false, false]
      expect(subject.bank_holiday_running).to be_nil
      expect(subject.status).to be_nil
      expect(subject.category).to be_nil
      expect(subject.signalling_headcode).to be_nil
      expect(subject.reservation_headcode).to be_nil
      expect(subject.service_code).to be_nil
      expect(subject.power_type).to be_nil
      expect(subject.timing_load).to be_nil
      expect(subject.speed).to be_nil
      expect(subject.operating_characteristics).to be_nil
      expect(subject.seating_class).to be_nil
      expect(subject.sleeping_class).to be_nil
      expect(subject.reservations).to be_nil
      expect(subject.catering).to be_nil
      expect(subject.branding).to be_nil
      expect(subject.stp_indicator).to eq :permanent
    end
  end

  it '#to_cif' do
    origin = double RailFeeds::NetworkRail::Schedule::TrainSchedule::Location::Origin
    change = double RailFeeds::NetworkRail::Schedule::TrainSchedule::ChangeEnRoute
    intermediate = double RailFeeds::NetworkRail::Schedule::TrainSchedule::Location::Intermediate
    terminating = double RailFeeds::NetworkRail::Schedule::TrainSchedule::Location::Terminating
    subject.journey = [origin, change, intermediate, terminating]

    expect(origin).to receive(:to_cif).and_return("origin\n")
    expect(change).to receive(:to_cif).and_return("change\n")
    expect(intermediate).to receive(:to_cif).and_return("intermediate\n")
    expect(terminating).to receive(:to_cif).and_return("terminating\n")

    expect(subject.to_cif).to eq [
      line_basic,
      line_extra,
      'origin',
      'change',
      'intermediate',
      'terminating'
    ].map { |i| "#{i}\n" }.join
  end

  it '#to_json' do
    subject = described_class.from_json json
    expect(subject.to_json).to eq json
  end

  describe '#<=>' do
    # By start daste then uid
    let(:train1) { described_class.new start_date: Date.new(2000, 1, 1), uid: 9999 }
    let(:train2) { described_class.new start_date: Date.new(2000, 1, 2), uid: 1000 }
    let(:train3) { described_class.new start_date: Date.new(2000, 1, 2), uid: 2000 }

    it 'Match' do
      train1a = described_class.new start_date: Date.new(2000, 1, 1), uid: 9999
      expect(train1 <=> train1a).to eq 0
      expect(train1a <=> train1).to eq 0
    end

    it 'Doesn\'t match' do
      expect(train1 <=> train2).to eq(-1)
      expect(train1 <=> train3).to eq(-1)
      expect(train2 <=> train1).to eq 1
      expect(train2 <=> train3).to eq(-1)
      expect(train3 <=> train1).to eq 1
      expect(train3 <=> train2).to eq 1
    end

    it 'Compares to nil without error' do
      expect { train1 <=> nil }.to_not raise_error
    end
  end

  describe '#==' do
    let(:train1) { described_class.new }
    let(:train2) { described_class.new }
    before :each do
      train1.uid = train2.uid = 'a01234'
      train1.start_date = train2.start_date = Date.new(1, 2, 3)
    end

    it 'Matches on neither :uid or :start_date' do
      train1.uid = nil
      train1.start_date = nil
      expect(train1).to_not eq train2
    end

    it 'Matches on :uid only' do
      train1.start_date = nil
      expect(train1).to_not eq train2
    end

    it 'Matches on :start_date only' do
      train1.uid = nil
      expect(train1).to_not eq train2
    end

    it 'Matches on both :uid or :start_date' do
      expect(train1).to eq train2
    end

    it 'Compares to nil without error' do
      expect(train1).to_not eq nil
    end
  end

  it_behaves_like 'it has an STP indicator'
  it_behaves_like 'it has a days array'
end
