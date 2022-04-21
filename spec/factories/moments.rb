FactoryBot.define do
  factory :moment do
    description { 'test' }
    file_path { 'aa-bb-cc.png' }
    link { 'https://example.com' }
  end
end