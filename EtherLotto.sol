// SPDX-License-Identifier: UNLICENSED

pragma solidity >= 0.4.11;
contract EtherLotto {
	// 투자자 구조체
	struct Player {
		address payable addr;	// 투자자의 어드레스
		uint nums;
	}

	address payable public owner;		// 컨트랙트 소유자
	uint public numPlayers;	// 투자자 수
	uint public deadline;		// 마감일 (UnixTime)
	string public status;		// 모금활동 상태
	bool public ended;			// 모금 종료여부
	uint public goalAmount  = 0.5 ether;		// 목표액 = 30 ether
	uint public totalAmount = 0;	// 총 투자액
	bool public alreadyState;   // 중복된 사용자 확인
	mapping (uint => Player) public players;	// 투자자 관리를 위한 매핑
	uint public round = 0;

	// 당첨자 정보
	address payable[] public winnerAddress;
	uint public numWinner;      // 당첨자 수
	uint public winningNum; // 당첨 번호
	uint public randNum;    // 난수

	modifier onlyOwner () {
		require(msg.sender == owner);
		_;
	}

	/// 생성자
	constructor(uint _duration) {
		owner = msg.sender;

		// 마감일 설정 (Unixtime)
		deadline = block.timestamp + _duration;

		status = "Available for purchase Lotto";
		ended = false;

		numPlayers = 0;
		totalAmount = 0;
		numWinner = 0;
		alreadyState = false;
		winningNum = 0;
		round++;
	}

	/// 투자 시에 호출되는 함수
	function purchase(uint playerNum) payable public{
		// 모금이 끝났다면 처리 중단
		require(!ended);
		require(msg.value == 0.2 ether, "Just Pay 10 ETH"); // 10이더 이상일 때만 송금

		for (uint i=0;i<numPlayers;i++){
			if (msg.sender == players[i].addr) {
				alreadyState = true;
			}
		}

		require(!alreadyState, "Already Exist");

		Player storage play = players[numPlayers++];
		play.addr = msg.sender;
		play.nums = playerNum; // JS에서 받아와야 함
		totalAmount += msg.value;

	}

	/// 주소를 통해 조회하기
	function getMyNum (address InputAddress) public view returns(uint){
		for (uint i=0;i<numPlayers;i++){
			if (players[i].addr == InputAddress)
				return players[i].nums;
		}
		return 0;
	}

	/// 목표액 달성 여부 확인
	/// 그리고 목표 금액 성공/실패 여부에 따라 송금
	function pickWinner () payable public onlyOwner {
		// 모금이 끝났다면 처리 중단
		require(!ended);

		// 마감이 지나지 않았다면 처리 중단
		require(block.timestamp >= deadline);

		if(goalAmount <= totalAmount) {	// 모금 성공인 경우
			status = "Complete Success";
			// 컨트랙트 소유자에게 컨트랙트에 있는 모든 이더를 송금
			ended = true;
			randNum = getRandomNumber();	// 난수 생성
			winningNum = randNum % 3 + 1;
			for(uint i=0; i<numPlayers; i++){
				if(winningNum == players[i].nums){
					winnerAddress.push(players[i].addr);
					numWinner++;
				}
			}

			if (numWinner == 0) {
				for (uint i=0;i<numPlayers;i++){
    				if(!players[i].addr.send(0.2 ether)) {
    					revert();
    				}
			    }
			}
			else {
				for (uint j=0;j<numWinner;j++) {
					if(!winnerAddress[j].send(totalAmount/numWinner)) {
						revert();
					}
				}
			}
		}

		else {	// 모금 실패인 경우
			status = "Insufficient Amount";
			ended = true;

			// 각 투자자에게 투자금을 돌려줌
			for (uint i=0;i<numPlayers;i++){
				if(!players[i].addr.send(0.2 ether)) {
					revert();
				}
			}
		}
	}


	/// 컨트랙트를 소멸시키기 위한 함수
	function kill() public onlyOwner {
		selfdestruct(owner);
	}

	function getBalance() view public returns(uint){
		return address(this).balance;
	}

	// 당첨 숫자 뽑기
	function getRandomNumber() public view returns (uint) {
		return uint(keccak256(abi.encodePacked(block.timestamp, block.difficulty, numPlayers)));
	}

}
