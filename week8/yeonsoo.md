# 8장 ‘정확히 한 번’ 의미 구조

## 멱등적(idempotent) 프로듀서 
멱등적이다 == 동일한 작업 실행해도 한 번만 실행한 것과 결과가 같다. (프로듀서 재시도로 인한 중복 방지)
### 작동 원리 
- 멱등적 프로듀서 기능을 켜면 모든 메시지는 고유한 프로듀서 ID(PID)와 sequence number를 가지게 된다.
- 각 메시지의 고유한 식별자: 대상 토픽 및 파티션 + PID + Sequence number 
- 각 브로커는 해당 브로커에 할당한 모든 파티션들에 쓰여진 마지막 5개 메시지들을  추적하기 위해 이 고유 식별자를 사용 
- `max.in.flights.requests.per.connection(def=5,max=5`: 파티션별로 추적되어야 하는 시퀀스 넘버의 수를 제한하고 싶다면 해당 설정을 5 이하로 잡으면 된다. 
#### 작동 실패했을 경우 
1. 프로듀서 재시작 
- 프로듀서에 장애가 발생할 경우, 보통 새 프로듀서를 생성해서 장애가 난 프로듀서를 대체한다.
- 멱등적 프로듀서 기능이 켜있는 경우, 프로듀서는 프로듀서가 시작될 때 초기화 과정에서 카프카 브로커로부터 프로듀서 ID를 생성받는다.
- 기존 프로듀서가 작동을 멈췄다가 새 프로듀서가 투입된 이후 작동을 재개해도, 서로 다른 PID를 가졌기 때문에 기존 프로듀서는 좀비로 취급되지 않는다. 
2. 브로커 장애 
- 브로커에 장애가 발생할 경우, 컨트롤러는 장애가 난 브로커가 리더를 맡고 있는 파티션에 대해 새 리더를 선출하게 된다.
- 리더는 새 메시지가 쓰여질 때마다 인-메모리 프로듀서 상태에 저장된 최근 5개의 시퀀스 넘버를 업데이트한다.
- 팔로워 레플리카는 리더로부터 새로운 메시지를 복제할 때마다 자체적인 인-메모리 버퍼를 업데이트한다. 
- 즉, 팔로워가 리더가 되어도 이 버퍼를 활용해 중복처리를 진행한다.
- 만약 예전 리더가 복구된다면, 재시작 후에는 인-메모리 프로듀서 상태는 더 이상 메모리에 저장되어 있지 않다. 
- 그래서 복구 과정에 도움이 되도록 브로커는 종료되거나 새 세그먼트가 생성될 때마다 프로듀서 상태에 대한 스냅샷을 파일형태로 저장한다. 
#### 사용법 
- 프로듀서 설정에 `enable.idempotence=true`를 추가한다. 만약 acks=all이면 성능에는 큰 차이가 없다.
### Exactly Once Semantics (EOS) 구현하기 
- 중복 없이 정확히 한 번만 처리를 보장 

#### Transactional Producer 설정 
```
producer = Producer({
    'bootstrap.servers': brokers,
    'transactional.id': 'eos-transactions.py'
})
producer.init_transactions()
producer.begin_transaction()
```
- `transactional.id`: 프로듀서를 트랜잭션 모드로 동작
- 읽고 쓰는 모든 행동을 하나의 묶음으로 만든다. 

### 메시지 읽고 변환 (Consume and Transform)
```dockerfile
msg = consumer.poll(timeout=1.0)
processed_key, processed_value = process_input(msg)

```
- `consumer.poll()`로 메시지 읽어오기 
- process_input(msg)는 읽은 메시지의 key와 value를 Base64로 인코딩해서 변환

### 메시지 쓰기 
```
producer.produce(output_topic, processed_value, processed_key,
                 on_delivery=delivery_report)
```
- 변환한 메시지를 새로운 토픽(output_topic)에 보냄.

### Consumer offset과 함께 커밋 
- 매 100개의 메시지를 처리할 때마다 트랜잭션을 커밋
```dockerfile
if msg_cnt % 100 == 0:
    producer.send_offsets_to_transaction(
        consumer.position(consumer.assignment()),
        consumer.consumer_group_metadata())
    producer.commit_transaction()
    producer.begin_transaction()

```
- `send_offsets_to_transaction`: 현재 읽은 위치(offset)를 트랜잭션에 저장
- `commit_transaction`: 읽은 메시지들과 쓴 메시지들, offset을 한꺼번에 커밋.
- `begin_transaction`: 새 트랜잭션 시작.