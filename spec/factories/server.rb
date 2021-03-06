FactoryGirl.define do
  factory :server do |m|
    m.name 'server-01'
    m.virtual false
    m.processor_physical_count 4
    m.processor_reference "Xeon 2300"
    m.processor_cores_per_cpu 4
    m.processor_frequency_GHz 3.2
    m.memory_GB 42
    m.nb_disk 5
    m.disk_size 13
    m.disk_type "SAS"
    m.serial_number "12345"
  end

  factory :virtual, parent: :server do |m|
    m.name 'v-server-01'
    m.virtual true
  end

  factory :server_with_extensions, parent: :server do
    server_extensions {
      [ FactoryGirl.create(:server_extension),
        FactoryGirl.create(:server_extension_without_serial) ]
    }
  end
end
