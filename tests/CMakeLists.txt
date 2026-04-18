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
add_iptvxs_test(test_xtream_client)
add_iptvxs_test(test_m3u_parser)
add_iptvxs_test(test_server_repository)
add_iptvxs_test(test_category_repository)
add_iptvxs_test(test_channel_repository)
add_iptvxs_test(test_favorite_repository)
add_iptvxs_test(test_xmltv_parser)
add_iptvxs_test(test_programme_repository)
