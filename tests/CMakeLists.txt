find_package(Qt6 REQUIRED COMPONENTS Test)

function(add_iptvxs_test name)
    add_executable(${name} ${name}.cpp)
    target_link_libraries(${name} PRIVATE
        iptvxs-core
        Qt6::Test
    )
    add_test(NAME ${name} COMMAND ${name})
endfunction()

add_iptvxs_test(test_settings_repository)
