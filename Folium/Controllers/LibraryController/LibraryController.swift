//
//  LibraryController.swift
//  Folium
//
//  Created by Jarrod Norwell on 23/1/2024.
//

import Foundation
import Grape
import MetalKit
#if canImport(Sudachi)
import Sudachi
#endif
import UIKit

enum RoundedCorners {
    case all, bottom, none, top
}

class MinimalRoundedTextField : UITextField {
    init(_ placeholder: String, _ roundedCorners: RoundedCorners = .none, _ radius: CGFloat = 15) {
        super.init(frame: .zero)
        self.backgroundColor = .secondarySystemBackground
        self.placeholder = placeholder
        
        switch roundedCorners {
        case .all:
            self.layer.cornerCurve = .continuous
            self.layer.cornerRadius = radius
        case .bottom, .top:
            self.layer.cornerCurve = .continuous
            self.layer.cornerRadius = radius
            self.layer.maskedCorners = roundedCorners == .bottom ? [.layerMinXMaxYCorner, .layerMaxXMaxYCorner] : [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        case .none:
            break
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.insetBy(dx: 20, dy: 0)
    }
    
    override func placeholderRect(forBounds bounds: CGRect) -> CGRect {
        return editingRect(forBounds: bounds)
    }
    
    override func textRect(forBounds bounds: CGRect) -> CGRect {
        return editingRect(forBounds: bounds)
    }
}

class LibraryController : UICollectionViewController {
    var dataSource: UICollectionViewDiffableDataSource<Core, AnyHashable>! = nil
    var snapshot: NSDiffableDataSourceSnapshot<Core, AnyHashable>! = nil
    
    var cores: [Core]
    
    fileprivate var menu: UIMenu {
        let children: [UIMenuElement] = if UIDevice.current.systemVersion <= "16.4" {
            [
                UIAction(title: "TrollStore", state: UserDefaults.standard.bool(forKey: "useTrollStore") ? .on : .off, handler: { _ in
                    UserDefaults.standard.set(!UserDefaults.standard.bool(forKey: "useTrollStore"), forKey: "useTrollStore")
                    
                    self.navigationItem.setLeftBarButton(.init(image: .init(systemName: "gearshape.fill"), menu: self.menu), animated: true)
                })
            ]
        } else {
            []
        }
        
        return .init(children: children)
    }
    
    init(collectionViewLayout layout: UICollectionViewLayout, cores: [Core]) {
        self.cores = cores
        super.init(collectionViewLayout: layout)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.navigationBar.prefersLargeTitles = true
        title = "Library"
        view.backgroundColor = .systemBackground
        
        navigationItem.setLeftBarButton(.init(image: .init(systemName: "gearshape.fill"), menu: menu), animated: true)
        let systemVersion = UIDevice.current.systemVersion
        if systemVersion == "14.0" || (systemVersion >= "15.0" && systemVersion < "16.7") || systemVersion == "17.0" {
            navigationItem.leftBarButtonItem?.isEnabled = true
        } else {
            navigationItem.leftBarButtonItem?.isEnabled = false
        }
        
        let cytrusGameCellRegistration = UICollectionView.CellRegistration<GameCell, CytrusGame> { cell, indexPath, itemIdentifier in
            if let image = itemIdentifier.imageData.decodeRGB565(width: 48, height: 48) {
                cell.imageView.image = image
            } else {
                cell.missingImageView.image = .init(systemName: "slash.circle")
            }
            cell.set(itemIdentifier.title, itemIdentifier.publisher)
        }
        
        let grapeGameCellRegistration = UICollectionView.CellRegistration<GameCell, GrapeGame> { cell, indexPath, itemIdentifier in
            if !itemIdentifier.isGBA, let cgImage = self.cgImage(from: Grape.shared.icon(from: itemIdentifier.fileURL), width: 32, height: 32) {
                cell.imageView.image = .init(cgImage: cgImage)
            } else {
                cell.missingImageView.image = .init(systemName: "slash.circle")
            }
            cell.set(itemIdentifier.title, itemIdentifier.size)
        }
        
        let kiwiGameCellRegistration = UICollectionView.CellRegistration<GameCell, KiwiGame> { cell, indexPath, itemIdentifier in
            cell.missingImageView.image = .init(systemName: "slash.circle")
            cell.set(itemIdentifier.title, itemIdentifier.size)
        }
        
        let sudachiGameCellRegistration = UICollectionView.CellRegistration<GameCell, SudachiGame> { cell, indexPath, itemIdentifier in
            if let image = UIImage(data: itemIdentifier.imageData) {
                cell.imageView.image = image
            } else {
                cell.missingImageView.image = .init(systemName: "slash.circle")
            }
            cell.set(itemIdentifier.title, itemIdentifier.developer)
        }
        
        let importGamesCellRegistration = UICollectionView.CellRegistration<ImportGamesCell, String> { cell, indexPath, itemIdentifier in
            cell.set(itemIdentifier)
        }
        
        let supplementaryViewRegistration = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(elementKind: UICollectionView.elementKindSectionHeader) { supplementaryView, elementKind, indexPath in
            var contentConfiguration = UIListContentConfiguration.extraProminentInsetGroupedHeader()
            
            let sectionIdentifier = self.dataSource.sectionIdentifier(for: indexPath.section)
            if let sectionIdentifier = sectionIdentifier {
                contentConfiguration.text = sectionIdentifier.name.rawValue
                contentConfiguration.textProperties.color = .label
                contentConfiguration.secondaryText = sectionIdentifier.console.rawValue
                contentConfiguration.secondaryTextProperties.color = .secondaryLabel
                supplementaryView.contentConfiguration = contentConfiguration
            }
            
#if canImport(Sudachi)
            func bootOSButton() -> UIButton { // MARK: Sudachi only for now
                var bootOSButtonConfiguration = UIButton.Configuration.borderless()
                bootOSButtonConfiguration.buttonSize = .medium
                bootOSButtonConfiguration.image = .init(systemName: "power.circle.fill")?
                    .applyingSymbolConfiguration(.init(hierarchicalColor: .tintColor))
                
                return UIButton(configuration: bootOSButtonConfiguration, primaryAction: .init(handler: { _ in
                    let sudachiEmulationController = SudachiEmulationController(game: nil)
                    sudachiEmulationController.modalPresentationStyle = .fullScreen
                    self.present(sudachiEmulationController, animated: true)
                }))
            }
#endif
            
            func coreSettingsButton() -> UIButton {
                var coreSettingsButtonConfiguration = UIButton.Configuration.borderless()
                coreSettingsButtonConfiguration.buttonSize = .medium
                coreSettingsButtonConfiguration.image = .init(systemName: "gearshape.circle.fill")?
                    .applyingSymbolConfiguration(.init(hierarchicalColor: .tintColor))
                
                return UIButton(configuration: coreSettingsButtonConfiguration)
            }
            
            func importGamesButton() -> UIButton {
                var importGamesButtonConfiguration = UIButton.Configuration.borderless()
                importGamesButtonConfiguration.buttonSize = .medium
                importGamesButtonConfiguration.image = .init(systemName: "arrow.down.circle.fill")?
                    .applyingSymbolConfiguration(.init(hierarchicalColor: .tintColor))
                
                return UIButton(configuration: importGamesButtonConfiguration)
            }
            
            if let core = sectionIdentifier, !core.missingFiles.isEmpty {
                func missingFilesButton() -> UIButton {
                    var configuration = UIButton.Configuration.borderless()
                    configuration.buttonSize = .large
                    let hierarchalColor: UIColor = if core.missingFiles.contains(where: { $0.fileImportance == .required }) { .systemRed } else { .systemOrange }
                    configuration.image = .init(systemName: "exclamationmark.circle.fill")?
                        .applyingSymbolConfiguration(.init(hierarchicalColor: hierarchalColor))
                    
                    return UIButton(configuration: configuration, primaryAction: .init(handler: { _ in
                        let configuration = UICollectionViewCompositionalLayoutConfiguration()
                        configuration.interSectionSpacing = 20
                        
                        let missingFilesControllerCompositionalLayout = UICollectionViewCompositionalLayout(sectionProvider: { sectionIndex, layoutEnvironment in
                            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(44))
                            let item = NSCollectionLayoutItem(layoutSize: itemSize)
                            
                            let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
                            group.interItemSpacing = .fixed(20)
                            
                            let section = NSCollectionLayoutSection(group: group)
                            section.boundarySupplementaryItems = [
                                .init(layoutSize: .init(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(44)),
                                      elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)
                            ]
                            section.contentInsets = .init(top: 0, leading: 20, bottom: 0, trailing: 20)
                            section.interGroupSpacing = 20
                            
                            return section
                        }, configuration: configuration)
                        
                        let missingFilesController = UINavigationController(rootViewController: MissingFilesController(core: core, collectionViewLayout: missingFilesControllerCompositionalLayout))
                        missingFilesController.modalPresentationStyle = .fullScreen
                        self.present(missingFilesController, animated: true)
                    }))
                }
                
                supplementaryView.accessories = if core.console == .nSwitch {
                    [
                        .customView(configuration: .init(customView: missingFilesButton(), placement: .trailing())),
                        .customView(configuration: .init(customView: importGamesButton(), placement: .trailing())),
                        .customView(configuration: .init(customView: coreSettingsButton(), placement: .trailing()))
                    ]
                } else {
                    [
                        .customView(configuration: .init(customView: missingFilesButton(), placement: .trailing())),
                        .customView(configuration: .init(customView: importGamesButton(), placement: .trailing())),
                        .customView(configuration: .init(customView: coreSettingsButton(), placement: .trailing()))
                    ]
                }
                
#if canImport(Sudachi)
                supplementaryView.accessories.insert(.customView(configuration: .init(customView: bootOSButton(), placement: .trailing())), at: 1)
#endif
            } else {
                supplementaryView.accessories = [
                    .customView(configuration: .init(customView: importGamesButton(), placement: .trailing())),
                    .customView(configuration: .init(customView: coreSettingsButton(), placement: .trailing()))
                ]
                
#if canImport(Sudachi)
                if sectionIdentifier?.console == .nSwitch {
                    supplementaryView.accessories.insert(.customView(configuration: .init(customView: bootOSButton(), placement: .trailing())), at: 0)
                }
#endif
            }
        }
        
        dataSource = .init(collectionView: collectionView) { collectionView, indexPath, itemIdentifier in
            switch itemIdentifier {
            case let string as String:
                collectionView.dequeueConfiguredReusableCell(using: importGamesCellRegistration, for: indexPath, item: string)
#if canImport(Cytrus)
            case let cytrusGame as CytrusGame:
                collectionView.dequeueConfiguredReusableCell(using: cytrusGameCellRegistration, for: indexPath, item: cytrusGame)
#endif
            case let grapeGame as GrapeGame:
                collectionView.dequeueConfiguredReusableCell(using: grapeGameCellRegistration, for: indexPath, item: grapeGame)
            case let kiwiGame as KiwiGame:
                collectionView.dequeueConfiguredReusableCell(using: kiwiGameCellRegistration, for: indexPath, item: kiwiGame)
#if canImport(Sudachi)
            case let sudachiGame as SudachiGame:
                collectionView.dequeueConfiguredReusableCell(using: sudachiGameCellRegistration, for: indexPath, item: sudachiGame)
#endif
            default:
                nil
            }
        }
        
        dataSource.supplementaryViewProvider = { collectionView, elementKind, indexPath in
            collectionView.dequeueConfiguredReusableSupplementary(using: supplementaryViewRegistration, for: indexPath)
        }
        
        snapshot = .init()
        snapshot.appendSections(cores.sorted())
        cores.forEach { core in
            if !core.missingFiles.contains(where: { $0.fileImportance == .required }), !core.games.isEmpty {
                switch core.games {
#if canImport(Cytrus)
                case let cytrusGames as [CytrusGame]:
                    snapshot.appendItems(cytrusGames.sorted(), toSection: core)
#endif
                case let grapeGames as [GrapeGame]:
                    snapshot.appendItems(grapeGames.sorted(), toSection: core)
                case let kiwiGames as [KiwiGame]:
                    snapshot.appendItems(kiwiGames.sorted(), toSection: core)
#if canImport(Sudachi)
                case let sudachiGames as [SudachiGame]:
                    Sudachi.shared.insert(games: sudachiGames.reduce(into: [URL](), { $0.append($1.fileURL) }))
                    snapshot.appendItems(sudachiGames.sorted(), toSection: core)
#endif
                default:
                    break
                }
            }
        }
        
        Task {
            await dataSource.apply(snapshot)
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemsAt indexPaths: [IndexPath], point: CGPoint) -> UIContextMenuConfiguration? {
        .init(previewProvider: {
            guard let indexPath = collectionView.indexPathForItem(at: point), let cell = collectionView.cellForItem(at: indexPath) as? GameCell else {
                return .init()
            }
            
            let vc = UIViewController()
            let imageView = UIImageView(image: cell.imageView.image ?? cell.missingImageView.image)
            imageView.contentMode = .scaleAspectFit
            vc.view = imageView
            vc.preferredContentSize = cell.imageView.frame.size
            
            return vc
        }, actionProvider:  { _ in
                .init(children: [
                    UIMenu(title: "Boot Options", image: .init(systemName: "power"), children: [
                        UIAction(title: "Boot Custom", handler: { _ in }),
                        UIAction(title: "Boot Global", handler: { _ in }),
                        UIAction(title: "Reset Custom", image: .init(systemName: "arrow.uturn.backward"), attributes: .destructive, handler: { _ in })
                    ]),
                    UIAction(title: "View Detailed", image: .init(systemName: "info"), handler: { _ in }),
                    UIMenu(title: "Content Options", image: .init(systemName: "questionmark.folder"), children: [
                        UIAction(title: "Install DLC", handler: { _ in }),
                        UIMenu(title: "Update Options", children: [
                            UIAction(title: "Install Update", handler: { _ in }),
                            UIAction(title: "Install & Delete Update", attributes: .destructive, handler: { _ in })
                        ])
                    ]),
                    UIAction(title: "Delete Game", image: .init(systemName: "trash"), attributes: .destructive, handler: { _ in })
                ])
        })
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        
        guard let object = dataSource.itemIdentifier(for: indexPath) else {
            return
        }
        
        switch object {
#if canImport(Cytrus)
        case let cytrusGame as CytrusGame:
            let cytrusEmulationController = CytrusEmulationController(game: cytrusGame)
            cytrusEmulationController.modalPresentationStyle = .fullScreen
            present(cytrusEmulationController, animated: true)
#endif
        case let grapeGame as GrapeGame:
            let grapeEmulationController = GrapeEmulationController(game: grapeGame)
            grapeEmulationController.modalPresentationStyle = .fullScreen
            present(grapeEmulationController, animated: true)
        case let kiwiGame as KiwiGame:
            let kiwiEmulationController = KiwiEmulationController(game: kiwiGame)
            kiwiEmulationController.modalPresentationStyle = .fullScreen
            present(kiwiEmulationController, animated: true)
#if canImport(Sudachi)
        case let sudachiGame as SudachiGame:
            let sudachiEmulationController = SudachiEmulationController(game: sudachiGame)
            sudachiEmulationController.modalPresentationStyle = .fullScreen
            present(sudachiEmulationController, animated: true)
#endif
        default:
            break
        }
    }
    
    fileprivate func cgImage(from screenFramebuffer: UnsafeMutablePointer<UInt32>, width: Int, height: Int) -> CGImage? {
        var imageRef: CGImage? = nil
        
        let colorSpaceRef = CGColorSpaceCreateDeviceRGB()
        
        let bitsPerComponent = 8
        let bytesPerPixel = 4
        let bitsPerPixel = bytesPerPixel * bitsPerComponent
        let bytesPerRow = bytesPerPixel * width
        let totalBytes = height * bytesPerRow
        
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue).union(.byteOrderDefault)
        guard let providerRef = CGDataProvider(dataInfo: nil, data: screenFramebuffer, size: totalBytes,
                                               releaseData: {_,_,_  in}) else {
            return nil
        }
        
        imageRef = CGImage(width: width, height: height, bitsPerComponent: bitsPerComponent, bitsPerPixel: bitsPerPixel,
                           bytesPerRow: bytesPerRow, space: colorSpaceRef, bitmapInfo: bitmapInfo, provider: providerRef,
                           decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        
        return imageRef
    }
}
