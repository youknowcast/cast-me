require 'rails_helper'

RSpec.describe FamilyUsageReport do
  around do |example|
    travel_to(Time.zone.parse('2026-11-23 12:00')) { example.run }
  end

  let(:family) { create(:family) }
  let(:alice) { create(:user, family: family, login_id: 'alice') }
  let(:bob) { create(:user, family: family, login_id: 'bob') }
  let(:report) { described_class.new(family: family, days: 7) }

  before do
    alice
    bob
  end

  def created_at_in_jst(value)
    Time.zone.parse(value)
  end

  describe '#date_range' do
    it 'covers the last 7 days including today in JST' do
      expect(report.start_date).to eq(Date.new(2026, 11, 17))
      expect(report.end_date).to eq(Date.new(2026, 11, 23))
    end
  end

  describe '#record_days' do
    it 'counts distinct days where a plan, task or meal was recorded' do
      create(:plan, family: family, created_by: alice, created_at: created_at_in_jst('2026-11-20 09:00'))
      create(:task, family: family, user: bob, created_at: created_at_in_jst('2026-11-20 21:00'))
      create(:meal, family: family, user: alice, created_at: created_at_in_jst('2026-11-22 12:00'))

      expect(report.record_days).to eq(2)
    end

    it 'ignores records before the period' do
      create(:plan, family: family, created_by: alice, created_at: created_at_in_jst('2026-11-16 23:30'))

      expect(report.record_days).to eq(0)
    end

    it 'ignores records from another family' do
      other_family = create(:family)
      other_user = create(:user, family: other_family)
      create(:plan, family: other_family, created_by: other_user, created_at: created_at_in_jst('2026-11-20 09:00'))

      expect(report.record_days).to eq(0)
    end

    it 'counts a record made just after midnight JST on the new day' do
      create(:plan, family: family, created_by: alice, created_at: created_at_in_jst('2026-11-17 00:30'))

      expect(report.record_days).to eq(1)
    end
  end

  describe 'counts per record type' do
    it 'counts plans, tasks and meals separately' do
      create(:plan, family: family, created_by: alice, created_at: created_at_in_jst('2026-11-20 09:00'))
      create(:plan, family: family, created_by: alice, created_at: created_at_in_jst('2026-11-21 09:00'))
      create(:task, family: family, user: bob, created_at: created_at_in_jst('2026-11-20 09:00'))
      create(:meal, family: family, user: bob, created_at: created_at_in_jst('2026-11-20 09:00'))

      expect(report.plan_count).to eq(2)
      expect(report.task_count).to eq(1)
      expect(report.meal_count).to eq(1)
    end
  end

  describe '#member_rows' do
    it 'returns every family member ordered by id' do
      expect(report.member_rows.map { |row| row.user.id }).to eq([alice.id, bob.id])
    end

    it 'counts record days per member' do
      create(:plan, family: family, created_by: alice, created_at: created_at_in_jst('2026-11-22 23:30'))
      create(:plan, family: family, created_by: alice, created_at: created_at_in_jst('2026-11-23 00:30'))
      create(:task, family: family, user: bob, created_at: created_at_in_jst('2026-11-22 09:00'))

      rows = report.member_rows.index_by { |row| row.user.id }
      expect(rows[alice.id].record_days).to eq(2)
      expect(rows[bob.id].record_days).to eq(1)
    end

    it 'does not count another family member records' do
      other_family = create(:family)
      other_user = create(:user, family: other_family)
      create(:plan, family: other_family, created_by: other_user, created_at: created_at_in_jst('2026-11-22 09:00'))

      expect(report.member_rows.map(&:record_days)).to eq([0, 0])
    end
  end

  describe '#last_seen_label' do
    it 'returns a dash when never seen' do
      expect(report.last_seen_label(alice)).to eq('—')
    end

    it 'returns 今日 for today' do
      alice.update!(last_seen_at: created_at_in_jst('2026-11-23 08:00'))
      expect(report.last_seen_label(alice)).to eq('今日')
    end

    it 'returns 昨日 for yesterday' do
      alice.update!(last_seen_at: created_at_in_jst('2026-11-22 23:00'))
      expect(report.last_seen_label(alice)).to eq('昨日')
    end

    it 'returns n日前 for within a month' do
      alice.update!(last_seen_at: created_at_in_jst('2026-11-18 08:00'))
      expect(report.last_seen_label(alice)).to eq('5日前')
    end

    it 'returns 30日以上前 after a month' do
      alice.update!(last_seen_at: created_at_in_jst('2026-10-01 08:00'))
      expect(report.last_seen_label(alice)).to eq('30日以上前')
    end
  end

  describe 'with a 30 day period' do
    it 'includes records older than a week' do
      create(:plan, family: family, created_by: alice, created_at: created_at_in_jst('2026-10-30 09:00'))

      monthly = described_class.new(family: family, days: 30)
      expect(report.plan_count).to eq(0)
      expect(monthly.plan_count).to eq(1)
    end
  end
end
