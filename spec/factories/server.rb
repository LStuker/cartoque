FactoryGirl.define do
  factory :server do |m|
    m.name 'server-01'
    m.virtual false
    m.nb_proc 4
    m.ref_proc "Xeon 2300"
    m.nb_coeur 4
    m.frequency 3.2
    m.memory 42
    m.nb_disk 5
    m.disk_size 13
    m.disk_type "SAS"
  end

  factory :virtual, parent: :server do |m|
    m.name 'v-server-01'
    m.virtual true
  end
end
