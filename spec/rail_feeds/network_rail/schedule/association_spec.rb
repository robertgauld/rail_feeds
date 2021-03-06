# frozen_string_literal: true

describe RailFeeds::NetworkRail::Schedule::Association do
  let(:line) do
    'AANmmmmmmaaaaaa0102030405060101010AcDTTTTTTT12T                                P'
  end
  subject { described_class.from_cif line }

  describe '::from_cif' do
    it 'Sets attributes' do
      expect(subject.main_train_uid).to eq 'mmmmmm'
      expect(subject.associated_train_uid).to eq 'aaaaaa'
      expect(subject.start_date).to eq Date.new(2001, 2, 3)
      expect(subject.end_date).to eq Date.new(2004, 5, 6)
      expect(subject.days).to eq [false, true, false, true, false, true, false]
      expect(subject.category).to eq 'Ac'
      expect(subject.date_indicator).to eq 'D'
      expect(subject.tiploc).to eq 'TTTTTTT'
      expect(subject.main_location_suffix).to eq 1
      expect(subject.associated_location_suffix).to eq 2
      expect(subject.stp_indicator).to eq :permanent
    end

    it 'Fails for invalid line' do
      expect { described_class.from_cif('bad line') }
        .to raise_error ArgumentError, "Invalid line:\nbad line"
    end

    it 'Delete line' do
      line = 'AADW43767W43768180529                ASHFKY   T                                C'
      subject = described_class.from_cif line
      expect(subject.main_train_uid).to eq 'W43767'
      expect(subject.associated_train_uid).to eq 'W43768'
      expect(subject.start_date).to eq Date.new(2018, 5, 29)
      expect(subject.end_date).to be_nil
      expect(subject.days).to eq [false, false, false, false, false, false, false]
      expect(subject.category).to be_nil
      expect(subject.date_indicator).to be_nil
      expect(subject.tiploc).to eq 'ASHFKY'
      expect(subject.main_location_suffix).to be_nil
      expect(subject.associated_location_suffix).to be_nil
      expect(subject.stp_indicator).to eq :stp_cancellation
    end
  end

  it '::from_json' do
    subject = described_class.from_json(
      '{"JsonAssociationV1":{"transaction_type":"Create","main_train_uid":"C69888",' \
      '"assoc_train_uid":"C69870","assoc_start_date":"2018-10-08T00:00:00Z",' \
      '"assoc_end_date":"2018-12-07T00:00:00Z","assoc_days":"1111100","category":"NP",' \
      '"date_indicator":"S","location":"NTNG","base_location_suffix":null,' \
      '"assoc_location_suffix":null,"diagram_type":"T","CIF_stp_indicator":"P"}}'
    )

    expect(subject.main_train_uid).to eq 'C69888'
    expect(subject.associated_train_uid).to eq 'C69870'
    expect(subject.start_date).to eq Date.new(2018, 10, 8)
    expect(subject.end_date).to eq Date.new(2018, 12, 7)
    expect(subject.days).to eq [true, true, true, true, true, false, false]
    expect(subject.category).to eq 'NP'
    expect(subject.date_indicator).to eq 'S'
    expect(subject.tiploc).to eq 'NTNG'
    expect(subject.main_location_suffix).to be_nil
    expect(subject.associated_location_suffix).to be_nil
    expect(subject.stp_indicator).to eq :permanent
  end

  describe 'Helper methods' do
    context 'Join association' do
      before(:each) { subject.category = 'JJ' }
      it { should be_join }
      it { should_not be_divide }
      it { should_not be_next }
    end

    context 'Divide association' do
      before(:each) { subject.category = 'VV' }
      it { should_not be_join }
      it { should be_divide }
      it { should_not be_next }
    end

    context 'Next association' do
      before(:each) { subject.category = 'NP' }
      it { should_not be_join }
      it { should_not be_divide }
      it { should be_next }
    end

    context 'Happens on the same day' do
      before(:each) { subject.date_indicator = 'S' }
      it { should be_same_day }
      it { should_not be_over_next_midnight }
      it { should_not be_over_previous_midnight }
    end

    context 'Happens over the following midnight' do
      before(:each) { subject.date_indicator = 'N' }
      it { should_not be_same_day }
      it { should be_over_next_midnight }
      it { should_not be_over_previous_midnight }
    end

    context 'Happens over the previous midnight' do
      before(:each) { subject.date_indicator = 'P' }
      it { should_not be_same_day }
      it { should_not be_over_next_midnight }
      it { should be_over_previous_midnight }
    end

    it '#main_train_event_id' do
      subject.tiploc = 'TTTTTTT'
      subject.main_location_suffix = 1
      expect(subject.main_train_event_id).to eq 'TTTTTTT-1'
    end

    it '#associated_train_event_id' do
      subject.tiploc = 'TTTTTTT'
      subject.associated_location_suffix = 2
      expect(subject.associated_train_event_id).to eq 'TTTTTTT-2'
    end
  end

  it '#to_cif' do
    expect(subject.to_cif).to eq "#{line}\n"
  end

  it '#to_json' do
    expect(subject.to_json).to eq '{"JsonAssociationV1":{"transaction_type":"Create",' \
                                  '"main_train_uid":"mmmmmm","assoc_train_uid":"aaaaaa",' \
                                  '"assoc_start_date":"2001-02-03T00:00:00Z",' \
                                  '"assoc_end_date":"2004-05-06T00:00:00Z",' \
                                  '"assoc_days":"0101010","category":"Ac",' \
                                  '"date_indicator":"D","location":"TTTTTTT",' \
                                  '"base_location_suffix":1,"assoc_location_suffix":2,' \
                                  '"diagram_type":"T","CIF_stp_indicator":"P"}}'
  end

  describe '#hash' do
    it 'Uses tiploc, main_location_suffix and associated_location_suffix' do
      subject.tiploc = 'TIPLOC'
      subject.main_location_suffix = 1
      subject.associated_location_suffix = 2
      expect(subject.hash).to eq 'TIPLOC-1-2'
    end
  end

  describe '#<=>' do
    let(:association1) { described_class.new start_date: Date.new(2000, 1, 1) }
    let(:association2) { described_class.new start_date: Date.new(2000, 1, 2) }

    it 'Match' do
      association2.start_date = Date.new 2000, 1, 1
      expect(association1 <=> association2).to eq 0
      expect(association2 <=> association1).to eq 0
    end

    it 'Doesn\'t match' do
      expect(association1 <=> association2).to eq(-1)
      expect(association2 <=> association1).to eq 1
    end

    it 'Compares to nil without error' do
      expect { association1 <=> nil }.to_not raise_error
    end
  end

  describe '#==' do
    let(:other_association) { double described_class }
    before :each do
      subject.tiploc = 'TTTTTTT'
      subject.main_location_suffix = 1
      subject.associated_location_suffix = 2
      allow(other_association).to receive(:main_train_event_id).and_return(nil)
      allow(other_association).to receive(:associated_train_event_id).and_return(nil)
    end

    it 'Matches on neither main or associated train\'s event' do
      expect(subject == other_association).to eq false
    end

    it 'Matches on main train\'s event only' do
      allow(other_association).to receive(:main_train_event_id).and_return('TTTTTTT-1')
      expect(subject == other_association).to eq false
    end

    it 'Matches on associated train\'s event only' do
      allow(other_association).to receive(:associated_train_event_id).and_return('TTTTTTT-2')
      expect(subject == other_association).to eq false
    end

    it 'Matches on both main and associated train\'s event' do
      allow(other_association).to receive(:main_train_event_id).and_return('TTTTTTT-1')
      allow(other_association).to receive(:associated_train_event_id).and_return('TTTTTTT-2')
      expect(subject == other_association).to eq true
    end

    it 'Compares to nil without error' do
      expect(subject).to_not eq nil
    end
  end

  it_behaves_like 'it has an STP indicator'
  it_behaves_like 'it has a days array'
end
