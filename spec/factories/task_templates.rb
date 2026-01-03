FactoryBot.define do
  factory :task_template do
    everyday_task_template
    user
    title { "洗顔" }
    description { "洗顔料を使って洗う" }
    priority { 0 }
  end
end
