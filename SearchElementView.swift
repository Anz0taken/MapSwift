//
//  SearchElementView.swift
//  Wowedo
//
//  Created by Luca Gargiulo on 12/11/23.
//

import SwiftUI
import MapKit

struct SearchElementView: View {
    @State private var selectedElementType: ElementType = .posts
    @State private var selectedViewType: ViewType = .list
    @State private var associatedNameArray: [ElementType: String] = [.posts:"post", .friends:"user", .categories:"event_category"]
    @State private var searchText: String = ""
    @State private var itemsList: [String] = []
    @State private var alreadyAdded: [Bool] = []
    @State private var idItemList: [Int] = []
    
    @State public var reSearchEvents: Bool = false
    @State public var filterSetting: FiltrerSettings = FiltrerSettings(selectedData: .now, selectedTime: .now, categories: [], tags: [], maxBuget: 0, inlcudeFurtherEvents: true)
    
    @State public var isSettingsModalPresented = false
    @State public var filterSettingsChanged = false
    @State var resetFilters: Bool = false
    @State var filtersOn: Bool = false;
    
    @State private var selectedElementTypeName = "post"
    
    @State public var initialPositioning: Bool = true
    
    @State public var isDetailViewPresented: Bool = false
    @State public var infoPointMapTapped: PostMapInfo = PostMapInfo(idPost: 0, postName: "", eventDate: "", eventTime: "", latitude: CLLocationDegrees(), longitude: CLLocationDegrees(), locationName: "", postDescription: "", image: Data())
    
    enum ElementType: String, CaseIterable {
        case posts = "Posts"
        case friends = "Friends"
        case categories = "Categories"
    }
    
    enum ViewType: String, CaseIterable {
        case list = "List"
        case map = "Map"
    }
    
    @State private var locationPoints: [PostMapInfo] = []
    
    @State private var selectedLocation: PostMapInfo?
    
    var body: some View {
        NavigationStack {
            VStack {
                Picker("", selection: $selectedElementType) {
                    ForEach(ElementType.allCases, id: \.self) { category in
                        Text(category.rawValue)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                .onChange(of: selectedElementType) {
                    selectedElementTypeName = associatedNameArray[selectedElementType]!
                    searchElements(selectedElementTypeName: selectedElementTypeName, textToSearch: searchText)
                }
                
                if selectedElementType == .posts {
                    Picker("", selection: $selectedViewType) {
                        ForEach(ViewType.allCases, id: \.self) { viewType in
                            Text(viewType.rawValue)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                    .onChange(of: selectedViewType) { _ in
                       
                    }
                }
                
                TextField("Search", text: $searchText)
                    .padding()
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
                    .padding()
                    .onChange(of: searchText) { newValue in
                        if selectedElementType == .posts && selectedViewType == .map
                        {
                            if let location = locationPoints.first(where: { $0.locationName.lowercased().contains(searchText.lowercased()) }) {
                                selectedLocation = location
                            }
                        }
                        else
                        {
                            searchElements(selectedElementTypeName: selectedElementTypeName, textToSearch: searchText)
                        }
                    }
                
                if selectedElementType == .posts && selectedViewType == .map
                {
                    MapView(locations: $locationPoints, searchText: $searchText, selectedLocation: $selectedLocation, shouldUpdateRegion: $initialPositioning) { tappedLocation in
                        infoPointMapTapped = tappedLocation
                        isDetailViewPresented = true
                    }
                    .frame(maxHeight: .infinity)
                    .cornerRadius(8)
                    .padding()
                    .onAppear {
                        getEventsList()
                    }
                    .navigate(to: DetailedPostView(selectedLocation: infoPointMapTapped), when: $isDetailViewPresented)
                }
                else
                {
                    List {
                        ForEach(itemsList.indices, id: \.self) { index in
                            let item = itemsList[index]
                            
                            if index < alreadyAdded.count {
                                let addedStatus = alreadyAdded[index]
                                
                                HStack {
                                    Text(item)
                                    Spacer()
                                    
                                    Button(action: {
                                        addOrRemoveElement(idItem: idItemList[index], toRemove: addedStatus, selectedElementTypeName: selectedElementTypeName)
                                    }) {
                                        Image(systemName: addedStatus ? "trash.fill" : "plus")
                                            .foregroundColor(addedStatus ? .red : .green)
                                            .padding(.trailing, 8)
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                }
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
                
                Spacer()
            }
            .navigationTitle("Search")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isSettingsModalPresented.toggle()
                    }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .imageScale(.large)
                            .foregroundColor(.primary)
                    }
                    .sheet(isPresented: $isSettingsModalPresented) {
                        if selectedElementType == .posts {
                            MapSettingsModal(isSettingsModalPresented: $isSettingsModalPresented, filterSettingsChanged: $filterSettingsChanged, resetFilters: $resetFilters, filterSetting: $filterSetting)
                            .onDisappear
                            {
                                if filterSettingsChanged {
                                    filtersOn = true
                                    filterSettingsChanged = false
                                    searchElements(selectedElementTypeName: selectedElementTypeName, textToSearch: searchText, filteredSetting: true)
                                    getEventsList()
                                }
                                else if resetFilters {
                                    filtersOn = false
                                    resetFilters = false
                                    searchElements(selectedElementTypeName: selectedElementTypeName, textToSearch: searchText)
                                    getEventsList()
                                }
                            }
                        } else {
                            Text("Other settings")
                        }
                    }
                }
            }
        }
        .onAppear{
            searchElements(selectedElementTypeName: selectedElementTypeName, textToSearch: searchText)
        }
    }
    
    func searchElements(selectedElementTypeName: String, textToSearch : String, filteredSetting: Bool = false) {
        do {
            if !filteredSetting
            {
                networkService.fetchData(from: URL(string: NetworkService.baseURL + "searchElementList.php?element="+textToSearch+"&type="+self.selectedElementTypeName)!) { (result: Result<Elementlist, Error>) in
                    switch result {
                    case .success(let response):
                        itemsList = response.itemsList
                        alreadyAdded = response.alreadyAdded
                        idItemList = response.idItemList
                    case .failure(let error):
                        print("Error: \(error)")
                    }
                }
            }
            else
            {
                var formattedDate: String {
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy-MM-dd"
                        return dateFormatter.string(from: filterSetting.selectedData)
                    }
                
                var formattedTime: String {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "HH:mm"
                    return dateFormatter.string(from: filterSetting.selectedTime)
                }
                
                if let urlString = URL(string: NetworkService.baseURL + "searchElementList.php?filtered=true&" +
                    "selectedData=\(formattedDate)&" +
                    "selectedTime=\(formattedTime)&" +
                    "categories=\(filterSetting.categories.joined(separator: ","))&" +
                    "tags=\(filterSetting.tags.joined(separator: ","))&" +
                    "maxBuget=\(filterSetting.maxBuget)&" +
                    "inlcudeFurtherEvents=\(filterSetting.inlcudeFurtherEvents)") {

                    networkService.fetchData(from: urlString) { (result: Result<Elementlist, Error>) in
                        switch result {
                        case .success(let response):
                            itemsList = response.itemsList
                        case .failure(let error):
                            print("Error: \(error)")
                        }
                    }
                }
            }
        }
    }
    
    func addOrRemoveElement(idItem: Int, toRemove: Bool, selectedElementTypeName: String) {
        do {
            networkService.fetchData(from: URL(string: NetworkService.baseURL + "addOrRemoveItem.php?toDelete=\(toRemove)&idElement=\(idItem)&type="+selectedElementTypeName)!) { (result: Result<BasicResponse, Error>) in
                switch result {
                case .success(let response):
                    searchElements(selectedElementTypeName: selectedElementTypeName, textToSearch: searchText)
                case .failure(let error):
                    print("Error: \(error)")
                }
            }
        }
    }
    
    func getEventsList() {
        do {
            if filtersOn {
                var formattedDate: String {
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy-MM-dd"
                        return dateFormatter.string(from: filterSetting.selectedData)
                    }
                
                var formattedTime: String {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "HH:mm"
                    return dateFormatter.string(from: filterSetting.selectedTime)
                }
                
                if let urlString = URL(string: NetworkService.baseURL + "getEventsList.php?filtered=true&" +
                    "selectedData=\(formattedDate)&" +
                    "selectedTime=\(formattedTime)&" +
                    "categories=\(filterSetting.categories.joined(separator: ","))&" +
                    "tags=\(filterSetting.tags.joined(separator: ","))&" +
                    "maxBuget=\(filterSetting.maxBuget)&" +
                    "inlcudeFurtherEvents=\(filterSetting.inlcudeFurtherEvents)") {

                    networkService.fetchData(from: urlString) { (result: Result<PostListResponse, Error>) in
                        switch result {
                        case .success(let response):
                            locationPoints = response.postList
                        case .failure(let error):
                            print("Error: \(error)")
                        }
                    }
                }
            }
            else
            {
                networkService.fetchData(from: URL(string: NetworkService.baseURL + "getEventsList.php?page=1")!) { (result: Result<PostListResponse, Error>) in
                    switch result {
                    case .success(let response):
                        locationPoints = response.postList
                    case .failure(let error):
                        print("Error: \(error)")
                    }
                }
            }
        }
    }
}

struct MapSettingsModal: View {
    @State private var selectedDate = Date()
    @State private var categories: [String] = []
    @State private var includeFutureEvents = false
    @State private var maxBudget: Int = 0
    @State private var isFreeSelected = false
    @State private var tags: [String] = []
    @State private var filteredCategories: [String] = []
    
    @State private var enteredCategory = ""
    @State private var enteredTag = ""
    
    @Binding var isSettingsModalPresented: Bool
    @Binding var filterSettingsChanged: Bool
    @Binding var resetFilters: Bool
    @Binding var filterSetting: FiltrerSettings
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Date and Time")) {
                    DatePicker("Select Date and Time", selection: $selectedDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(GraphicalDatePickerStyle())
                        .labelsHidden()

                    Toggle("Include Future Events", isOn: $includeFutureEvents)
                }

                Section(header: Text("Budget")) {
                    if !isFreeSelected {
                        TextField("Max Budget", value: $maxBudget, formatter: NumberFormatter())
                            .keyboardType(.numberPad)
                    }
                    Toggle("Free Events Only", isOn: $isFreeSelected)
                }
                
                Section(header: Text("Tags")) {
                    HStack {
                        TextField("Enter Tag", text: $enteredTag)
                        if !enteredTag.isEmpty {
                            Button(action: {
                                tags.append(enteredTag)
                                enteredTag = ""
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.blue)
                                    .imageScale(.large)
                            }
                        }
                    }

                    ForEach(tags, id: \.self) { tag in
                        HStack {
                            Text(tag)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                            Spacer()
                            Button(action: {
                                tags.removeAll { $0 == tag }
                            }) {
                                Image(systemName: "multiply.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                }

                Section(header: Text("Categories")) {
                    HStack {
                        TextField("Enter Category", text: $enteredCategory)
                            .onChange(of: enteredCategory) { newValue in
                                searchPersonalCategories(textToSearch: enteredCategory)
                            }
                    }
                    
                    if(enteredCategory.count > 0 && filteredCategories.count > 0)
                    {
                        ScrollView {
                            ForEach(filteredCategories, id: \.self) { category in
                                Button(action: {
                                    categories.append(category)
                                    enteredCategory = ""
                                    filteredCategories = []
                                }) {
                                    HStack {
                                        Text(category)
                                            .padding(.vertical, 8)
                                            .padding(.horizontal, 12)
                                        Spacer()
                                    }
                                }
                            }
                        }
                    }

                    List(categories, id: \.self) { category in
                        HStack {
                            Text(category)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                            Spacer()
                            Button(action: {
                                categories.removeAll { $0 == category }
                            }) {
                                Image(systemName: "multiply.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Reset") {
                        isSettingsModalPresented = false
                        resetFilters = true
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        filterSettingsChanged = true
                        applyFilters()
                        isSettingsModalPresented = false
                    }
                }
            }
            .navigationBarTitle("Map Filters")
        }
    }
    
    func searchPersonalCategories(textToSearch : String) {
        do {
            networkService.fetchData(from: URL(string: NetworkService.baseURL + "getPersonalCategoryList.php?is_clike=true&element=\(textToSearch)")!) { (result: Result<Elementlist, Error>) in
                switch result {
                case .success(let response):
                    filteredCategories = response.itemsList
                    filteredCategories.removeAll { categories.contains($0) }
                case .failure(let error):
                    print("Error: \(error)")
                }
            }
        }
    }
     
    func applyFilters() {
        filterSetting.categories = categories
        filterSetting.tags = tags
        if isFreeSelected {
            filterSetting.maxBuget = 0
        }
        else
        {
            filterSetting.maxBuget = maxBudget
        }
        filterSetting.selectedData = selectedDate
        filterSetting.selectedTime = selectedDate
        filterSetting.inlcudeFurtherEvents = includeFutureEvents
    }
}

extension View {
    func navigate<NewView: View>(to view: NewView, when binding: Binding<Bool>) -> some View {
        NavigationView {
            ZStack {
                self
                    .navigationBarTitle("")
                    .navigationBarHidden(true)

                NavigationLink(
                    destination: view
                        .navigationBarTitle("")
                        .navigationBarHidden(false),
                    isActive: binding
                ) {
                    EmptyView()
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}
