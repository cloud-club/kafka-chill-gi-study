
### replication_factor

```markdown
- default.replication.factor = 1
- offsets.topic.replication.factor = 3
- transaction.state.log.replication.factor = 1
```

```markdown
- KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR: 3
- KAFKA_TRANSACTION_STATE_LOG_MIN_ISR: 2
- KAFKA_DEFAULT_REPLICATION_FACTOR: 3
- KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 3
```

yaml 이해하기
- https://stackoverflow.com/questions/73849828/what-is-mean-plaintext-host
- https://stackoverflow.com/questions/51630260/connect-to-kafka-running-in-a-docker-container#51634499
- 
dump log
- https://soono-991.tistory.com/66

schma
https://forum.confluent.io/t/using-system-topic-schema/10002

- KAFKA_CLUSTER_ID 확인필요
- 주키퍼 <> 대화형 사용범
- 주키퍼 세션 ? 관련 로그 처리 방법
- 도커 볼륨 저장 방식 3가지 관리
- https://stackoverflow.com/questions/38532483/where-is-var-lib-docker-on-mac-os-x

```markdown
Preferred Replica: 파티션의 복제본 중 첫 번째 복제본을 "선호 복제본"이라고 하며, 가능하면 이 복제본이 리더가 되도록 설정됩니다. 이 로그는 모든 리더가 선호 복제본에 맞게 배치되었음을 보여줍니다.
Leader Imbalance Ratio: 리더 파티션 분배가 얼마나 불균형인지 나타내는 비율입니다. 0.0은 완벽한 균형을 의미합니다.
```