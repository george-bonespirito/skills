package com.example.domain.usecase

/** Sample source for Konsist to scope. Named `*UseCase`, lives in `..domain..`. */
class OrderUseCase {
    fun place(orderId: String): String = "placed:$orderId"
}
