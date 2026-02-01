//
//  ContentView.swift
//  KakeiboApp
//
//  Created by TAKUYA MUKAIYAMA on 2026/02/01.
//

import Charts
import SwiftUI

// データモデル
struct Transaction: Identifiable, Codable {
    var id = UUID()
    var date: Date
    var category: String
    var amount: Double
    var isIncome: Bool
    var memo: String
}

struct MonthlySummary: Identifiable {
    let month: Date
    let income: Double
    let expense: Double

    var id: Date { month }
}

struct ExpenseCategorySummary: Identifiable {
    let category: String
    let amount: Double

    var id: String { category }
}

// メインビュー
struct ContentView: View {
    @State private var transactions: [Transaction] = []
    @State private var showingAddSheet = false
    private let summaryColor = Color.purple
    
    var totalIncome: Double {
        transactions.filter { $0.isIncome }.reduce(0) { $0 + $1.amount }
    }
    
    var totalExpense: Double {
        transactions.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
    }
    
    var balance: Double {
        totalIncome - totalExpense
    }

    var monthlySummaries: [MonthlySummary] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: transactions) { transaction in
            calendar.date(from: calendar.dateComponents([.year, .month], from: transaction.date)) ?? transaction.date
        }

        return grouped.map { month, entries in
            let income = entries.filter { $0.isIncome }.reduce(0) { $0 + $1.amount }
            let expense = entries.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
            return MonthlySummary(month: month, income: income, expense: expense)
        }
        .sorted { $0.month < $1.month }
    }

    var expenseCategorySummaries: [ExpenseCategorySummary] {
        let expenses = transactions.filter { !$0.isIncome }
        let grouped = Dictionary(grouping: expenses, by: { $0.category })
        return grouped.map { category, entries in
            let amount = entries.reduce(0) { $0 + $1.amount }
            return ExpenseCategorySummary(category: category, amount: amount)
        }
        .sorted { $0.amount > $1.amount }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // サマリー表示
                HStack(spacing: 30) {
                    SummaryCard(title: "収入", amount: totalIncome, color: summaryColor)
                    SummaryCard(title: "支出", amount: totalExpense, color: summaryColor)
                    SummaryCard(title: "残高", amount: balance, color: summaryColor)
                }
                .padding()
                
                // グラフと取引リスト
                List {
                    Section(header: Text("グラフ")) {
                        VStack(alignment: .leading, spacing: 20) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("月別収支")
                                    .font(.headline)
                                if monthlySummaries.isEmpty {
                                    Text("取引を追加すると月別の収支グラフが表示されます。")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Chart {
                                        ForEach(monthlySummaries) { summary in
                                            LineMark(
                                                x: .value("月", summary.month, unit: .month),
                                                y: .value("金額", summary.income)
                                            )
                                            .foregroundStyle(by: .value("種別", "収入"))
                                            .symbol(by: .value("種別", "収入"))

                                            LineMark(
                                                x: .value("月", summary.month, unit: .month),
                                                y: .value("金額", summary.expense)
                                            )
                                            .foregroundStyle(by: .value("種別", "支出"))
                                            .symbol(by: .value("種別", "支出"))
                                        }
                                    }
                                    .chartXAxis {
                                        AxisMarks(values: .stride(by: .month)) { value in
                                            AxisValueLabel(format: .dateTime.year().month(.twoDigits))
                                        }
                                    }
                                    .frame(height: 220)
                                }
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("カテゴリ別支出")
                                    .font(.headline)
                                if expenseCategorySummaries.isEmpty {
                                    Text("支出があるとカテゴリ別の内訳が表示されます。")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Chart {
                                        ForEach(expenseCategorySummaries) { summary in
                                            SectorMark(
                                                angle: .value("金額", summary.amount),
                                                innerRadius: .ratio(0.6)
                                            )
                                            .foregroundStyle(by: .value("カテゴリ", summary.category))
                                        }
                                    }
                                    .chartLegend(position: .bottom, alignment: .leading)
                                    .frame(height: 240)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }

                    Section(header: Text("取引履歴")) {
                        ForEach(transactions.sorted(by: { $0.date > $1.date })) { transaction in
                            TransactionRow(transaction: transaction)
                        }
                        .onDelete(perform: deleteTransaction)
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            .navigationTitle("家計簿")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddTransactionView(transactions: $transactions)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    func deleteTransaction(at offsets: IndexSet) {
        transactions.remove(atOffsets: offsets)
    }
}

// サマリーカード
struct SummaryCard: View {
    let title: String
    let amount: Double
    let color: Color
    
    var body: some View {
        VStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            Text("¥\(amount, specifier: "%.0f")")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(15)
    }
}

// 取引行
struct TransactionRow: View {
    let transaction: Transaction
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(transaction.category)
                    .font(.headline)
                Text(transaction.memo)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(transaction.date, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("\(transaction.isIncome ? "+" : "-")¥\(transaction.amount, specifier: "%.0f")")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(transaction.isIncome ? .green : .red)
        }
        .padding(.vertical, 5)
    }
}

// 取引追加ビュー
struct AddTransactionView: View {
    @Binding var transactions: [Transaction]
    @Environment(\.presentationMode) var presentationMode
    
    @State private var date = Date()
    @State private var category = ""
    @State private var amount = ""
    @State private var isIncome = false
    @State private var memo = ""
    
    let expenseCategories = ["食費", "交通費", "娯楽", "光熱費", "通信費", "その他"]
    let incomeCategories = ["給与", "賞与", "副業", "その他"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("種類")) {
                    Picker("取引種類", selection: $isIncome) {
                        Text("支出").tag(false)
                        Text("収入").tag(true)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(header: Text("詳細")) {
                    DatePicker("日付", selection: $date, displayedComponents: .date)
                    
                    Picker("カテゴリ", selection: $category) {
                        ForEach(isIncome ? incomeCategories : expenseCategories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                    
                    TextField("金額", text: $amount)
                        .keyboardType(.numberPad)
                    
                    TextField("メモ", text: $memo)
                }
            }
            .navigationTitle("取引を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveTransaction()
                    }
                    .disabled(category.isEmpty || amount.isEmpty)
                }
            }
        }
        .onAppear {
            if !expenseCategories.isEmpty {
                category = expenseCategories[0]
            }
        }
    }
    
    func saveTransaction() {
        guard let amountValue = Double(amount) else { return }
        
        let transaction = Transaction(
            date: date,
            category: category,
            amount: amountValue,
            isIncome: isIncome,
            memo: memo
        )
        
        transactions.append(transaction)
        presentationMode.wrappedValue.dismiss()
    }
}

#Preview {
    ContentView()
}
