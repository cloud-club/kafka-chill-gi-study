# Chapter1. 카프카 시작하기 
## 1.1 발행/구독 메시지 전달 
- 발행/구독 메시지 전달 패턴
  - 전송자(발행하는 쪽)가 데이터(메시지)를 보낼 때 직접 수신자(구독하는 쪽)으로 보내지 않는다
- 개별 주체 간 디커플링? 스키마 변경되어도 내부에서 처리해준다? 
- 단일 consumer는 여러 파티션을 할당 받을 수 있습니다. 
- 그렇다면 카프카만이 가지고 있는 이 특성은 어떤 장단점을 가지고 있을까요?
  컨슈머 그룹에서 한 컨슈머는 하나 이상의 파티션을 처리할 수 있습니다. 그러면 한 파티션을 동일한 consumer group에 있는 서로 다른 컨슈머가 처리할 수 있나요?

디스커션 
Kafka가 Netty를 사용하지 않고 직접 네트워크 계층을 구현한 이유는:

- epoll 기반의 고성능 I/O Multiplexing을 직접 컨트롤하기 위해.
- Zero-Copy를 최적화하여 불필요한 메모리 복사를 줄이기 위해.
- 불필요한 기능을 제거하고 Kafka에 최적화된 네트워크 계층을 설계하기 위해.
- 백프레셔 및 네트워크 튜닝을 유연하게 하기 위해.
- 이러한 최적화 덕분에 Kafka는 초당 수십만 개의 메시지를 처리하는 초고성능 메시징 시스템이 될 수 있었습니다. ?

https://www.yuki-dev-blog.site/data-engineering/kafka/kafka-core-guide/1

# Chapter2. 환경 설정 
https://brunch.co.kr/@peter5236/13
- **파티션 수** (p29)
  - 늘리면 다시 줄일 수 없으니, 늘리면 안된다. 


# Chapter3. 
- 3.0버전 이후 ack=all 을 설정하면 enable.idempotence=true가 자동 활성화된다. 
- acks=all 사용이 속도저하가 없다
- 파이어 앤 포겟(동기적 전송) (p54)
  - get을 쓰면 비동기가 동기로 바뀌어 버림. 그래서 카프카 프로듀서는 언제나 비동기로 작동되지만, 동기적 전송이 되는 것임. 
  - 메시지와 콜백을 함께 넣어서 배치 단위로 비동기적 전송된다?
  - ack? 
- 시리얼라이저? 
- send()
  - producer.send를 호출하였을 때 일어나는 작업은 어떻게 될까?
- producer는 스레드 세이프하지만, 컨슈머는 그렇지 않음. 

https://www.yuki-dev-blog.site/data-engineering/kafka/kafka-core-guide/3