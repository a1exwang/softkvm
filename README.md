# softkvm

- Features
    - Software implemented KVM switch
        - Management server: ruby mux.rb
        - Keyboard server: cat /dev/input/eventXXX | nc -k management_server_ip 8223
        - Keyboard client: nc -k management_server_ip 8223 | ./build/vinput CUSTOM_INPUT_DEVICE_NAME
        - On any where: telnet management_server_ip 8222
            - ls
            - cp SERVER_ID kbs
            - en in SERVER_ID
            - cp CLIENT_ID kbs
            - en out CLIENT_ID
    - Monitoring keyboard status
        - ruby server.rb (will list all input devices' names and device file path)
    - Report keyboard statistics
        - cat /dev/input/eventXXX | ruby keyboard_mon.rb > a.mon
        - ruby stats/key_stats.rb < a.mon