# Kafka chapter4: Kafka Producer ✏

## Kafka 프로듀서란?

Kafka 프로듀서는 데이터를 **토픽(Topic)** 으로 보내는 역할을 한다. 데이터가 들어오면 Kafka가 이를 저장하고, 소비자(Consumer)가 가져갈 수 있도록 해준다. 
큰 흐름으로 보자면 아래처럼 정리해 볼 수 있다.

1. 프로듀서가 **메시지를 생성**한다.
2. 메시지를 **토픽 안의 특정 파티션(Partition)** 으로 보낸다.
3. **Kafka 브로커(Broker)** 가 메시지를 받아 저장한다.
4. 소비자가 나중에 이를 가져간다.

발신자가 이메일을 보낼 때, 메일 서버가 메시지를 중간에서 받아서 보관하고, 수신자가 이를 꺼내보는 것과 비슷하고, Kafka도 메시지를 이런 방식으로 전달한다.

#

## Kafka Consumer
Kafka에서 **Consumer(소비자)**는 프로듀서가 보낸 메시지를 **토픽(Topic)**에서 가져와 처리하는 역할을 한다.
이 과정에서 메시지가 어떻게 전달되는지, Consumer Group(소비자 그룹)은 어떤 역할을 하는지 자세히 살펴보자.

Kafka Consumer는 Kafka Broker에서 메시지를 읽어오는 역할을 한다.
Kafka는 메시지를 특정 파티션(Partition)에 저장하며, Consumer는 이를 오프셋(Offset) 을 기준으로 읽어간다.
이러한 메시지 처리는 순서 보장을 위해 특정한 방식으로 동작한다.
![image](https://github.com/user-attachments/assets/c5e3f443-7079-487a-b3ff-040bc5ac8aaf)

**[동작 순서]**
1) Consumer는 Kafka 브로커에서 Topic의 특정 Partition을 할당받아 메시지를 가져간다.
2) 메시지를 처리한 후, 오프셋(Offset)을 커밋(Commit) 하여 현재 읽은 위치를 저장한다.
3) Consumer는 다음 메시지를 요청하여 처리하고, 지속적으로 반복한다.
 
Kafka Consumer는 메시지를 자동으로 Push 받는 것이 아니라, 직접 요청하여(Pull) 가져가며, Consumer는 Offset을 이용해 읽을 위치를 기억하고, 필요할 경우 다시 읽을 수도 있다.
한 Consumer가 여러 개의 파티션을 할당받을 수 있으며, 반대로 여러 Consumer가 같은 Topic을 구독할 수도 있다.


## Kasfa Consumer Group
Consumer Group은 여러 Consumer가 협력하여 하나의 Topic을 처리하는 그룹을 의미한다.
각 Consumer는 동일한 Topic의 다른 Partition을 나누어 가져가서 병렬 처리할 수 있다.

하나의 Consumer Group은 하나의 논리적 Consumer처럼 동작한다.
1개의 Partition은 Consumer Group별로 가지는 것이 아니고, 1개의 Consumer에만 할당되며
여러 Consumer Group이 동일한 Topic을 구독할 수 있다. (즉, 서로 다른 Group은 같은 데이터를 독립적으로 처리할 수 있다. ???)

Consumer Group을 구성할 때, Consumer가 추가되거나 제거되면 Kafka가 자동으로 리밸런싱(Rebalancing)을 수행한다.

### Offset 관리
Kafka Consumer는 어디까지 읽었는지 기억하기 위해 Offset을 저장한다.
이 Offset을 어떻게 관리하느냐에 따라 데이터 재처리 또는 손실 가능성이 달라진다. 크게 커밋 방식과 리밸런싱 방식이 있는데, 아래에서 자세히 살펴보자.


- 자동 커밋(enable.auto.commit=true)

Kafka가 자동으로 Offset을 주기적으로 커밋한다. 실시간 처리가 빠르지만, 메시지 손실 가능성이 존재한다.


- 수동 커밋(enable.auto.commit=false)

Consumer가 직접 메시지를 처리한 후 commitSync() 또는 commitAsync()를 호출하여 Offset을 저장
장애 발생 시 다시 읽을 수 있어 신뢰성이 높다.

- Rebalancing (리밸런싱)
Consumer가 새로 추가되거나 제거될 때, Kafka는 자동으로 Partition을 재배치한다.
이를 **Rebalancing(재조정)**이라고 하며, 이 과정에서는 잠시 메시지 처리가 중단될 수도 있다.

#
#
**[Kafka Consumer에서 발생하는 Offset 관리 문제]**


**1) Reprocessed Messages**
![image](https://github.com/user-attachments/assets/adfa6e73-25a6-44fd-bb5d-e83a0c9cc3b4)
Consumer가 특정 메시지를 처리하는 도중 Rebalance(재조정) 가 발생하면, 이미 읽은 메시지를 다시 처리할 가능성이 있다.
이때, 마지막으로 커밋된 오프셋이 오래된 상태라면 이전 메시지들이 다시 처리되면서 중복이 발생할 수 있다.
consumer가 메시지를 처리하던 중에 rebalance가 발생했을 때 특정 offset지점부터 다시 시작을 하는데, 처리중이었던 범위 중 이미 처리한 메시지가 다시 소비되면서 중복 처리가 발생할 수 있다.

-> 자동 커밋(Auto Commit) 비활성화 후, 메시지 처리 후 수동으로 Offset을 Commit 한다.



**2) Missed Messages**
![image](https://github.com/user-attachments/assets/7828d4bb-767f-4619-9860-f1f6f0d5393d)
Consumer가 메시지를 처리하는 동안 Offset을 너무 빨리 커밋하면, 장애 발생 시 일부 메시지가 누락될 가능성이 있다고 한다.
메시지 1~5를 가져왔는데 4번까지만 처리하고 5번을 커밋해버리면 5번은 누락이 되어버리는 것이다.

-> 이때도 수동 커밋을 사용해서 메시지가 완전히 처리된 후 커밋될 수 있도록 조치를 해줄 수 있다.
## 메시지는 어떻게 보내질까?  

Kafka 프로듀서는 단순히 메시지를 보내는 것이 아니라, 이를 어디에 저장할지 결정하는 과정도 포함한다.
아래 관련 중요한 개념을 살펴보자.

### (1) ProducerRecord: Kafka에 보낼 메시지  
Kafka에서 프로듀서가 보내는 메시지는 `ProducerRecord<K, V>` 형태로 되어 있다. 
key-value 형태로 메시지가 보내지고, 여기서 `K`는 Key, `V`는 Value를 의미한다.

- **Key**: 특정 파티션에 메시지를 할당할 때 사용된다.  
  예를 들어, 같은 사용자 ID를 Key로 사용하면 항상 같은 파티션에 데이터가 저장이 된다.
- **Value**: 실제로 저장할 데이터이다.
- **Topic**: 데이터를 보낼 대상 토픽을 지정한다.

만약 Key 없이 메시지를 보낸다면 Kafka는 알아서 임의로 데이터를 여러 파티션에 분배해준다.

### (2) 직렬화
Kafka는 데이터를 저장할 때 바이트 배열(Byte Array)로 변환해야 한다. 이를 위해 직렬화를 거친다.  
직렬화 방식의 종류가 여러 종류가 있는데, 자주 사용하는 직렬화 방식은 다음과 같다.

- `StringSerializer`: 문자열을 UTF-8 바이트 배열로 변환  
- `IntegerSerializer`: 정수를 바이트 배열로 변환  
- `ByteArraySerializer`: 바이트 배열을 그대로 유지  

데이터를 효과적으로 보내려면 적절한 직렬화 방식을 선택해야 한다.

### (3) 메시지 라우팅 (Partitioning)  
Kafka는 데이터를 파티션(Partition)단위로 저장한다.  
메시지를 보낼 때, 어느 파티션으로 보낼지를 결정하는 방식은 3가지가 있다.

1. **Key 기반 라우팅**: 같은 Key를 가진 메시지는 항상 같은 파티션으로 간다.  
2. **라운드 로빈 방식**: Key가 없을 경우, 메시지를 여러 파티션에 골고루 분배한다.  
3. **사용자 정의 방식**: 직접 파티션을 정하는 커스텀 로직을 구현할 수도 있다.  

#

## 프로듀서 설정 옵션 정리  

Kafka 프로듀서는 다양한 설정이 가능한데, 그 중에서 중요한 설정 몇가지이다.

- `bootstrap.servers`: Kafka 브로커 주소 
- `key.serializer` / `value.serializer`: Key와 Value를 직렬화하는 방식  
- `acks`: 메시지 전송 성공을 확인하는 방법 ex) 0 혹은 1 혹은 all
- `batch.size`: 메시지를 묶어서 한 번에 보내는 크기 
- `linger.ms`: 배치를 위해 대기하는 시간 
- `compression.type`: 메시지 압축 방식  
- `retries`: 메시지 전송 실패 시 재시도 횟수

이 중에서도 `acks`는 데이터의 신뢰성을 결정하는 중요한 옵션이다.

아래처럼 acks를 어떻게 설정하느냐에 따라서 데이터 전송 속도와 안전성간의 trade-off가 발생한다.(목적에 맞게 선택...)
- acks=0: 메시지를 보내고 확인하지 않음 (가장 빠르지만 데이터 손실 위험)  
- acks=1: 리더(Leader) 브로커가 메시지를 받으면 확인 응답 (기본값)  
- acks=all: 모든 복제(Replica)가 메시지를 받을 때까지 기다림 (가장 안전하지만 속도 저하)  

데이터 손실 없이 안정적인 전송이 필요하다면 `acks=all`로 설정하는 것이 좋다.

#

## Kafka 성능 최적화에 대하여...

Kafka는 기본적으로 빠른 성능을 제공하지만, 몇 가지 최적화 기법을 사용하면 더 빠르고 효율적인 데이터 전송이 가능하다.

### (1) Batching
Kafka는 네트워크 비용을 줄이기 위해 여러 개의 메시지를 한 번에 묶어 보낼 수 있다.

- batch.size를 늘리면 성능이 향상될 수 있다.
- linger.ms 값을 설정하면 메시지를 조금 더 모은 후 한 번에 전송한다.

예를 들어 `linger.ms=5`로 설정하면, Kafka가 5ms 동안 메시지를 모아 배치를 만들어 보낸다.

### (2) Compression 
Kafka는 데이터를 압축해서 전송할 수도 있다.

- `gzip`: 높은 압축률이지만 CPU 사용량 증가  
- `snappy`: 빠르지만 압축률이 낮음  
- `lz4`: 속도와 압축률의 균형이 좋음  
- `zstd`: 최신 압축 방식으로 높은 성능 제공  

압축을 사용하면 네트워크 트래픽을 줄일 수 있어 성능이 좋아진다.

### (3) Asynchronous Send
Kafka 프로듀서는 기본적으로 asynchronous하게 메시지를 보낸다.  
즉, 메시지를 보낸 뒤 응답을 기다리지 않고 바로 다음 작업을 수행할 수 있다.

```java
producer.send(record, (metadata, exception) -> {
    if (exception == null) {
        System.out.println("Sent message: " + metadata.offset());
    } else {
        exception.printStackTrace();
    }
});
