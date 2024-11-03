# == Schema Information
#
# Table name: moments
#
#  id          :bigint           not null, primary key
#  description :string(255)
#  file_path   :string(255)
#  link        :string(255)      not null
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
