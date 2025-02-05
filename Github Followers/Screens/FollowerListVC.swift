//
//  FolloweListVC.swift
//  Github Followers
//
//  Created by Abdirizak Hassan on 10/24/21.
//

import UIKit

class FollowerListVC: GFDataLoadingVC {

    enum Section { case main }
    
    var username: String!
    var followers: [Follower] = []
    var filterFollowers: [Follower] = []
    var page = 1
    var hasMoreFollowers = true
    var isSearching = false
    var isLoadingMoreFollowers = false
    
    var collectionView: UICollectionView!
    var dataSource: UICollectionViewDiffableDataSource<Section, Follower>!
    
    init(username: String){
        super.init(nibName: nil, bundle: nil)
        self.username   = username
        title           = username
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationController?.navigationBar.prefersLargeTitles = true
        let addBtn = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addBtnTapped))
        navigationItem.rightBarButtonItem = addBtn
        ConfigureSearchController()
        configureCollectionView()
        getFollowers(username: username, page: page)
        configureDataSource()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: true)
    }
    
    @objc func addBtnTapped() {
        showLoadingview()
        
        NetworkManger.shared.getUserInfo(for: username) { [weak self] result in
            guard let self = self else { return }
            self.dismissLoding()
            switch result {
            case.success(let user):
                let favorite = Follower(login: user.login, avatar_url: user.avatar_url)
                
                PersistenceManager.updateWith(favorite: favorite, actionType: .add) { [weak self] error in
                    guard let self = self else { return }
                    
                    guard let error = error else {
                        self.presentGFAlertOnMainThread(title: "Success!", message: "You have successfull favorite this user 🎉", buttonTitle: "Ok")
                        return
                    }
                    
                    self.presentGFAlertOnMainThread(title: "Something Wrong", message: error.rawValue, buttonTitle: "ok")
                }
            case .failure(let error):
                self.presentGFAlertOnMainThread(title: "Something Wrong", message: error.rawValue, buttonTitle: "Ok")
            }
        }
        
    }
    
    func getFollowers(username: String, page: Int) {
        showLoadingview()
        isLoadingMoreFollowers = true
        NetworkManger.shared.getFollowers(for: username, page: page) { [weak self] result in
            guard let self = self else { return }
            self.dismissLoding()
            switch result {
            case .success(let followers):
                self.updateUI(with: followers)
            case .failure(let error):
                self.presentGFAlertOnMainThread(title: "Bad Stuff Happen", message: error.rawValue, buttonTitle: "Ok")
            }
            self.isLoadingMoreFollowers = false
        }
    }
    
    func updateUI(with follower: [Follower]) {
        if follower.count < 100 { self.hasMoreFollowers = false}
        self.followers.append(contentsOf: follower)
        if self.followers.isEmpty {
            let message = "This user doesn't have any followers. Go follow them..."
            DispatchQueue.main.async {
                self.showEmptyStateView(with: message, in: self.view)
            }
            return
        }
        self.updateData(on: self.followers)
    }
    
    func configureCollectionView() {
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: UIHelper.createThreeCulomnFlowLayout(in: view))
        view.addSubview(collectionView)
        collectionView.delegate = self
        collectionView.backgroundColor = .systemBackground
        collectionView.register(FollowerCell.self, forCellWithReuseIdentifier: FollowerCell.identifier)
    }
    
    
    func ConfigureSearchController() {
        let searchController                                    = UISearchController()
        searchController.searchResultsUpdater                   = self
        searchController.searchBar.placeholder                  = "Search for a username"
        searchController.obscuresBackgroundDuringPresentation   = false
        navigationItem.searchController                         = searchController
    }
    
    
    
    func configureDataSource() {
        dataSource = UICollectionViewDiffableDataSource<Section, Follower>(collectionView: collectionView, cellProvider: { (collectionView, indexPath, follower) -> UICollectionViewCell? in
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FollowerCell.identifier, for: indexPath) as? FollowerCell
            cell?.set(follower: follower)
            return cell
        })
    }
    
    
    func updateData(on followers: [Follower]) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Follower>()
        snapshot.appendSections([.main])
        snapshot.appendItems(followers)
        DispatchQueue.main.async { self.dataSource.apply(snapshot, animatingDifferences: true) }
    }
    
}


extension FollowerListVC: UICollectionViewDelegate {
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        let offSetY = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let height = scrollView.frame.size.height
        
        if offSetY > contentHeight - height {
            guard hasMoreFollowers, !isLoadingMoreFollowers  else { return }
            page += 1
            getFollowers(username: username, page: page)
        }
    }
    
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let activeArray = isSearching ? filterFollowers : followers
        let follower = activeArray[indexPath.item]
        
        let destVC = UserInfoVC()
        destVC.username = follower.login
        destVC.delegate = self
        let navigationController = UINavigationController(rootViewController: destVC)
        present(navigationController, animated: true)
        
        
    }
    
    
}


extension FollowerListVC: UISearchResultsUpdating {
    
    func updateSearchResults(for searchController: UISearchController) {
        guard let filter = searchController.searchBar.text, !filter.isEmpty else {
            filterFollowers.removeAll()
            updateData(on: followers)
            isSearching = false
            return
        }
        isSearching = true
        filterFollowers = followers.filter { $0.login.lowercased().contains(filter.lowercased()) }
        updateData(on: filterFollowers)
    }
    
    
}

extension FollowerListVC: UserInfoVCDelegate {
    func didRequestFollowers(for username: String) {
        // Get followers for that user
        self.username   = username
        title           = username
        page = 1
        followers.removeAll()
        filterFollowers.removeAll()
//        collectionView.setContentOffset(.zero, animated: true)
        collectionView.scrollToItem(at: IndexPath(item: 0, section: 0), at: .top, animated: true)
        getFollowers(username: username, page: page)
    }
    
    
}
