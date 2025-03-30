helloworld

https://stackoverflow.com/questions/48498414/kafka-topic-creation-best-practice


기본 동작: MSK의 DNS 엔드포인트는 단일 IP를 반환하도록 설정되어 있어, client.dns.lookup=default로 작동합니다. 
즉, 클라이언트는 MSK가 제공하는 DNS 이름에 대해 기본 DNS 조회를 수행하고 단일 IP로 연결을 시도합니다.


맞는지 확인필요



````markdown
By default, Kafka validates, resolves, and creates connections based on the hostname
provided in the bootstrap server configuration (and later in the names returned by
the brokers as specified in the advertised.listeners configuration).
````