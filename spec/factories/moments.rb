# == Schema Information
#
# Table name: moments
#
#  id          :integer          not null, primary key
#  description :string
#  file_path   :string
#  link        :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
FactoryBot.define do
  factory :moment do
    description { 'test' }
    file_path { 'aa-bb-cc.png' }
    link { 'https://example.com' }
  end
end
