docker hub 가 있다는 가정하에 해당 yaml 제작 및 테스트 하시면 됩니다~!

문서에 따르면, KAFKA_ADVERTISED_HOST_NAME는 본인의 docker host ip로 수정ㅋ
multi broker를 사용하지 않을 것이므로, localhost(127.0.0.1)을 작성

작성 후 바로 다음 명령어 실행 (이것을 실행한 bash 말고 다른 bash 에서 작업을 이어나가야 함)


## 컨테이너 실행

docker-compose -f kafka-compose.yaml up



## new bash 에서 다음 명령어 계속~~

```
docker exec -it kafka /bin/bash
```

```
kafka-topics.sh --create --topic topic1 --bootstrap-server localhost:9092 --replication-factor 1 --partitions 3
```

하나의 토픽에  3개의 파티션을 만드는 것임



### 간단한 테트 명령어

토픽 리스트 확인: kafka-topics.sh --list --bootstrap-server localhost:9092
토픽 상세 조회: kafka-topics.sh --describe --topic topic1 --bootstrap-server kafka:9092


토픽 삭제: kafka-topics.sh --delete --bootstrap-server kafka:9092 --topic topic1



## 컨슈머 실행하기!!

```
cd /opt/kafka_2.12-2.5.0/bin/
./kafka-console-consumer.sh --topic topic1 --bootstrap-server kafka:9092
```

## 프로듀서 실행

다시 새로운  bash 를 하나 더 열고

```
docker exec -it kafka /bin/bash
cd /opt/kafka_2.12-2.5.0/bin/
./kafka-console-producer.sh --topic topic1 --broker-list kafka:9092
```

hello kafka 를 실행해보고 (컨슈머에서) 정상 작동하는 지 확인하면 끝!

컨슈머에 돌아오면 실행되었다는 걸 확인할 수 있다!


### 최종 종료

docker-compose 컨테이너는 다음 명령어로 내린다.
```
docker-compose -f kafka-compose.yaml down
```


### 참고했던 블로그

https://9hyuk9.tistory.com/92
https://dkswnkk.tistory.com/705
